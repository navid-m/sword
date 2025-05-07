require "yaml"
require "uri"
require "json"
require "http/client"
require "colorize"
require "file_utils"
require "../src/logs"
require "../src/dirs"
require "../src/inits"
require "../src/meta"
require "../src/shards_interop"

PKGFILE     = "shard.yml"
CACHEDIR    = File.join(get_home_directory, ".sword", "cache")
HOSTS       = {
    "github.com"   => "github",
    "gitlab.com"   => "gitlab",
    "codeberg.org" => "codeberg"
}

FileUtils.mkdir_p(CACHEDIR) unless Dir.exists?(CACHEDIR)

def git_url_to_dependency(url : String) : NamedTuple(name: String, repo: String, provider: String)
    uri = URI.parse(url)
    provider = HOSTS[uri.host]?
    unless provider
        abort "Unsupported git host: #{uri.host}"
    end
    parts = uri.path.split("/").reject(&.empty?)
    if parts.size < 2
        abort "Invalid git URL format"
    end
    name = parts.last.downcase
    repo = "#{parts[0]}/#{parts[1]}"
    return {name: name, repo: repo, provider: provider}
end

def load_shard_yml : Hash(YAML::Any, YAML::Any)
    begin
        yaml_raw = YAML.parse(File.read(PKGFILE))
        return yaml_raw.as_h
    rescue
        abort "No #{PKGFILE} was found in the current directory."
    end
end

def read_shard_yml : Array(String)
    begin
        File.read_lines(PKGFILE)
    rescue
        abort "No #{PKGFILE} was found in the current directory."
    end
end

def write_shard_yml(lines : Array(String))
    File.write(PKGFILE, lines.join("\n"))
end

def search_packages(query : String)
    print_info "Searching for packages matching '#{query}'..."

    begin
        response = HTTP::Client.get(
            "https://api.github.com/search/repositories?q=#{URI.encode_www_form(query)}+language:crystal&sort=stars&order=desc"
        )

        if response.status_code == 200
            results = JSON.parse(response.body)

            if results["items"].as_a.size > 0
                print_title "Search Results"

                results["items"].as_a[0..9].each_with_index do |item, index|
                    repo_name = item["full_name"].as_s
                    description = item["description"].as_s? || "No description"
                    stars = item["stargazers_count"].as_i
                    url = item["html_url"].as_s

                    puts "#{index + 1}. #{repo_name.colorize(:green)} (#{stars})"
                    puts "   #{description}"
                    puts "   #{url.colorize(:blue)}"
                    puts ""
                end

                print_info "To add a package: sword get [URL]"
            else
                print_warning "No packages found matching '#{query}'"
            end
        else
            print_error "Failed to search packages: #{response.status_code}"
        end
    rescue ex
        print_error "Error searching packages: #{ex.message}"
    end
end

def show_dependency_tree
    if !File.exists?("shard.lock")
        print_warning "No shard.lock file found. Run 'sword update' to generate one."
        return
    end

    begin
        yaml = YAML.parse(File.read("shard.lock"))
        deps = yaml["shards"].as_h
        deps.each do |name, info|
            version = info["version"]?.try(&.as_s) || "unknown"
            puts "#{name} (#{version})".colorize(:green)
            if info["dependencies"]?.try(&.as_h)
                info["dependencies"].as_h.each do |dep_name, _|
                    puts "  └── #{dep_name}".colorize(:blue)
                end
            end
        end
    rescue ex
        print_error "Error parsing shard.lock: #{ex.message}"
    end
end

def add_dependency(url : String, version : String? = nil)
    dep = git_url_to_dependency(url)
    print_info "Adding dependency: #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}"
    lines                       = read_shard_yml
    dependencies_index          = -1
    dependencies_indentation    = ""

    lines.each_with_index do |line, index|
        if line =~ /^(\s*)dependencies\s*:/
            dependencies_index = index
            dependencies_indentation = $1
            break
        end
    end

    if dependencies_index == -1
        lines << "" if lines.last != ""
        lines << "dependencies:"
        dependencies_index = lines.size - 1
        dependencies_indentation = ""
    end

    dep_name = dep[:name]
    dep_start_index = -1
    dep_end_index = -1

    (dependencies_index + 1).upto(lines.size - 1) do |i|
        break if i >= lines.size || lines[i] =~ /^\S/ && !lines[i].starts_with?("#")
        if lines[i] =~ /^\s+#{Regex.escape(dep_name)}\s*:/
            dep_start_index = i

            j = i + 1
            while j < lines.size && (lines[j].empty? || lines[j].starts_with?("#") || lines[j] =~ /^\s+/)
                if lines[j] =~ /^(\s+)/ && $1.size > lines[i].index(/\S/).not_nil!
                    dep_end_index = j
                end
                j += 1
            end

            break
        end
    end

    dep_indentation  = "#{dependencies_indentation}  "
    prop_indentation = "#{dependencies_indentation}    "

    dep_lines = ["#{dep_indentation}#{dep_name}:"]
    dep_lines << "#{prop_indentation}#{dep[:provider]}: #{dep[:repo]}"
    dep_lines << "#{prop_indentation}version: #{version}" if version

    if dep_start_index != -1
        lines.delete_at(dep_start_index..dep_end_index)
        dep_lines.each_with_index do |line, idx|
            lines.insert(dep_start_index + idx, line)
        end
    else
        insert_index = dependencies_index + 1

        while insert_index < lines.size &&
              (lines[insert_index].empty? ||
               lines[insert_index].starts_with?("#") ||
               lines[insert_index] =~ /^\s+/)
            insert_index += 1
        end

        dep_lines.each_with_index do |line, idx|
            lines.insert(insert_index + idx, line)
        end
    end

    write_shard_yml(lines)

    print_success "Added dependency #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}#{version ? " with version #{version}" : ""}."

    if shards_available?
        update_and_prune
    end
end

def remove_dependency(url : String)
    dep = git_url_to_dependency(url)
    print_info "Removing dependency: #{dep[:name]}"

    lines = read_shard_yml
    dependencies_index = -1

    lines.each_with_index do |line, index|
        if line =~ /^(\s*)dependencies\s*:/
            dependencies_index = index
            break
        end
    end

    if dependencies_index == -1
        print_warning "Dependency: #{dep[:name]} not found, nothing to remove."
        return
    end

    dep_name = dep[:name]
    dep_start_index = -1
    dep_end_index = -1
    dep_indentation = nil

    (dependencies_index + 1).upto(lines.size - 1) do |i|
        break if i >= lines.size || (lines[i] =~ /^\S/ && !lines[i].starts_with?("#"))

        if lines[i] =~ /^(\s+)#{Regex.escape(dep_name)}\s*:/
            dep_start_index = i
            dep_indentation = $1.size

            j = i + 1
            while j < lines.size
                if !lines[j].empty? && !lines[j].starts_with?("#") && lines[j] =~ /^(\s*)\S/
                    current_indent = $1.size
                    if current_indent <= dep_indentation
                        break
                    end
                    dep_end_index = j
                end
                j += 1
            end

            break
        end
    end

    if dep_start_index != -1
        if dep_end_index != -1
            lines.delete_at(dep_start_index..dep_end_index)
        else
            lines.delete_at(dep_start_index)
        end

        has_other_deps = false
        (dependencies_index + 1).upto(lines.size - 1) do |i|
            break if i >= lines.size || (lines[i] =~ /^\S/ && !lines[i].starts_with?("#"))
            if lines[i] =~ /^\s+\S+\s*:/
                has_other_deps = true
                break
            end
        end

        if !has_other_deps
            lines.delete_at(dependencies_index)
        end

        write_shard_yml(lines)

        print_success "Removed dependency #{dep[:name]}."
        if shards_available?
            update_and_prune
        end
    else
        print_warning "Dependency: #{dep[:name]} not found, nothing to remove."
    end
end

def clean_cache
    print_info "Cleaning cache directory: #{CACHEDIR}"

    if Dir.exists?(CACHEDIR)
        FileUtils.rm_rf(CACHEDIR)
        FileUtils.mkdir_p(CACHEDIR)
        print_success "Cache cleaned."
    else
        print_warning "Cache directory doesn't exist. Nothing to clean."
    end
end

def fetch_shard_info(url : String)
    dep = git_url_to_dependency(url)
    print_info "Fetching information for #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}"

    case dep[:provider]
    when "github"
        fetch_github_info(dep[:repo], dep[:name])
    when "gitlab"
        fetch_gitlab_info(dep[:repo], dep[:name])
    when "codeberg"
        fetch_codeberg_info(dep[:repo], dep[:name])
    else
        print_error "Unsupported provider: #{dep[:provider]}"
    end
end

def fetch_github_info(repo : String, name : String)
    begin
        repo_response = HTTP::Client.get(
            "https://api.github.com/repos/#{repo}",
            headers: HTTP::Headers{"Accept" => "application/vnd.github.v3+json"}
        )

        if repo_response.status_code != 200
            print_error "Failed to fetch repository information: HTTP #{repo_response.status_code}"
            return
        end

        repo_data        = JSON.parse(repo_response.body)
        content_response = HTTP::Client.get(
            "https://api.github.com/repos/#{repo}/contents/shard.yml",
            headers: HTTP::Headers{"Accept" => "application/vnd.github.v3+json"}
        )

        shard_data = {} of String => String
        if content_response.status_code == 200
            content = JSON.parse(content_response.body)
            if content["content"]?
                begin
                    decoded   = Base64.decode_string(content["content"].as_s)
                    yaml      = YAML.parse(decoded)

                    shard_data["version"] = yaml["version"]?.try(&.as_s) || "Unknown"
                    shard_data["crystal"] = yaml["crystal"]?.try(&.as_s) || "Any"
                    shard_data["license"] = yaml["license"]?.try(&.as_s) || "Unknown"
                    shard_data["description"] = yaml["description"]?.try(&.as_s) || "No description"
                rescue
                    # Continue...
                end
            end
        end

        puts "Name:         #{name}".colorize(:green)
        puts "Repository:   #{repo_data["html_url"].as_s}"
        puts "Description:  #{repo_data["description"].as_s? || "No description"}"
        puts "Stars:        #{repo_data["stargazers_count"].as_i}"
        puts "Forks:        #{repo_data["forks_count"].as_i}"
        puts "Open Issues:  #{repo_data["open_issues_count"].as_i}"
        puts "Last Updated: #{repo_data["updated_at"].as_s}"
        puts "License:      #{shard_data["license"]? || repo_data["license"].try(&.["name"].as_s?) || "Unknown"}"

        if shard_data["version"]?
            puts "Version:      #{shard_data["version"]}"
        end

        if shard_data["crystal"]?
            puts "Crystal:      #{shard_data["crystal"]}"
        end

        puts "\nTo add this package:"
        puts "  sword get #{repo_data["html_url"].as_s}".colorize(:yellow)

    rescue ex
        print_error "Error fetching information: #{ex.message}"
    end
end

def fetch_gitlab_info(repo : String, name : String)
    begin
        repo_encoded = URI.encode_www_form(repo)
        repo_response = HTTP::Client.get(
            "https://gitlab.com/api/v4/projects/#{repo_encoded}"
        )

        if repo_response.status_code != 200
            print_error "Failed to fetch repository information: HTTP #{repo_response.status_code}"
            return
        end

        repo_data = JSON.parse(repo_response.body)
        print_title "#{name} Information"
        puts "Name:         #{name}".colorize(:green)
        puts "Repository:   #{repo_data["web_url"].as_s}"
        puts "Description:  #{repo_data["description"].as_s? || "No description"}"
        puts "Stars:        #{repo_data["star_count"].as_i}"
        puts "Forks:        #{repo_data["forks_count"].as_i}"
        puts "Open Issues:  #{repo_data["open_issues_count"].as_i}"
        puts "Last Updated: #{repo_data["last_activity_at"].as_s}"
        puts "License:      #{repo_data["license"].try(&.["name"].as_s?) || "Unknown"}"

        puts "\nTo add this package:"
        puts "  sword get #{repo_data["web_url"].as_s}".colorize(:yellow)

    rescue ex
        print_error "Error fetching information: #{ex.message}"
    end
end

def fetch_codeberg_info(repo : String, name : String)
    begin
        repo_encoded  = URI.encode_www_form(repo)
        repo_response = HTTP::Client.get(
            "https://codeberg.org/api/v1/repos/#{repo_encoded}"
        )

        if repo_response.status_code != 200
            print_error "Failed to fetch repository information: HTTP #{repo_response.status_code}"
            return
        end

        repo_data = JSON.parse(repo_response.body)
        print_title "#{name} Information"

        puts "Name:         #{name}".colorize(:green)
        puts "Repository:   #{repo_data["html_url"].as_s}"
        puts "Description:  #{repo_data["description"].as_s? || "No description"}"
        puts "Stars:        #{repo_data["stars_count"].as_i}"
        puts "Forks:        #{repo_data["forks_count"].as_i}"
        puts "Open Issues:  #{repo_data["open_issues_count"].as_i}"
        puts "Last Updated: #{repo_data["updated_at"].as_s}"

        puts "\nTo add this package:"
        puts "  sword get #{repo_data["html_url"].as_s}".colorize(:yellow)

    rescue ex
        print_error "Error fetching information: #{ex.message}"
    end
end

case ARGV[0]?
when "tidy"
    if !prune()
        print_error "Shards executable was not available, nothing tidied."
    end
when "b"
    build_args = ARGV.size > 1 ? ARGV[1..] : [] of String
    build_project(build_args)
when "get"
    if ARGV.size < 2
        print_error "Usage: sword get <package-url> [version]"
        exit 1
    end
    version = ARGV[2]? if ARGV.size > 2
    add_dependency(ARGV[1], version)
when "rm"
    if ARGV.size < 2
        print_error "Usage: sword rm <package-url>"
        exit 1
    end
    remove_dependency(ARGV[1])
when "search"
    if ARGV.size < 2
        print_error "Usage: sword search <query>"
        exit 1
    end
    search_packages(ARGV[1])
when "c"
    if ARGV.size < 2
        print_error "Usage: sword c <file.cr>"
        exit 1
    end
    compile_single(ARGV[1])
when "init"
    if ARGV.size < 2
        print_error "Usage: sword init <name>"
        exit 1
    end
    init_project(ARGV[1])
when "info"
    if ARGV.size < 2
        print_error "Usage: sword info <package-url>"
        exit 1
    end
    fetch_shard_info(ARGV[1])
when "up"
    update_and_prune
when "br"
    build_project_release
when "bs"
    build_project_static
when "clean"
    clean_cache
when "version"
    show_version
when "deps"
    show_dependency_tree
when "about"
    show_about
when "help", nil
    show_help
else
    print_error "Unknown command: #{ARGV[0]}"
    show_help
    exit 1
end
