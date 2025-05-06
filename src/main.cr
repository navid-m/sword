require "yaml"
require "uri"
require "json"
require "http/client"
require "colorize"
require "file_utils"
require "../src/logs"
require "../src/dirs"
require "../src/shard_interop"

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

def build_project(args : Array(String) = [] of String)
    if shards_available?
        build_command = ["shards", "build"]
        build_command.concat(args)
        print_info "Building project with: #{build_command.join(" ")}"
        system(build_command.join(" "))
    else
        print_error "shards executable not available in path, skipping build."
    end
end

def load_shard_yml : Hash(YAML::Any, YAML::Any)
    begin
        yaml_raw = YAML.parse(File.read(PKGFILE))
        return yaml_raw.as_h
    rescue
        abort "No #{PKGFILE} was found in the current directory."
    end
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

                    puts "#{index + 1}. #{repo_name.colorize(:green)} (#{stars}⭐)"
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

def init_project(name : String)
    if Dir.exists?(name)
        print_error "Directory '#{name}' already exists"
        return
    end

    print_info "Initializing new project: #{name}"
    Dir.mkdir_p(name)

    %w(src spec).each do |dir|
        Dir.mkdir_p("#{name}/#{dir}")
    end
    File.write("#{name}/src/#{name}.cr", <<-CRYSTAL
    module #{name.camelcase}
      VERSION = "0.1.0"

      # TODO: Add your code here
    end
    CRYSTAL
    )
    File.write("#{name}/spec/spec_helper.cr", <<-CRYSTAL
    require "spec"
    require "../src/#{name}"
    CRYSTAL
    )

    File.write("#{name}/spec/#{name}_spec.cr", <<-CRYSTAL
    require "./spec_helper"
    describe #{name.camelcase} do
      # TODO: Add tests here
      it "works" do
        #{name.camelcase}.should be_truthy
      end
    end
    CRYSTAL
    )

    File.write("#{name}/shard.yml", <<-YAML
    name: #{name}
    version: 0.1.0

    authors:
      - Your Name <your.email@example.com>

    description: |
      A short description of #{name}

    crystal: ">= 1.0.0"

    development_dependencies:
      ameba:
        github: crystal-ameba/ameba

    license: MIT
    YAML
    )

    File.write("#{name}/.gitignore", <<-GITIGNORE
    /docs/
    /lib/
    /bin/
    /.shards/
    *.dwarf
    GITIGNORE
    )

    print_success "Project created in ./#{name}/"
    print_info "Run 'cd #{name} && sword build' to build your project"
end

def add_dependency(url : String, version : String? = nil)
    yaml         = load_shard_yml
    deps_key     = YAML::Any.new("dependencies")
    deps         = yaml[deps_key]?.try(&.as_h) || {} of YAML::Any => YAML::Any
    dep          = git_url_to_dependency(url)
    dep_name_key = YAML::Any.new(dep[:name])

    print_info "Adding dependency: #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}"

    dep_entry = {YAML::Any.new(dep[:provider]) => YAML::Any.new(dep[:repo])}

    if version
        dep_entry[YAML::Any.new("version")] = YAML::Any.new(version)
    end

    deps[dep_name_key]  = YAML::Any.new(dep_entry)
    yaml[deps_key]      = YAML::Any.new(deps)

    File.write(
        PKGFILE,
        YAML::Any.new(yaml).to_yaml
    )

    print_success "Added dependency #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}#{version ? " with version #{version}" : ""}."

    if shards_available?
        update_and_prune
    end
end

def remove_dependency(url : String)
    yaml = load_shard_yml
    deps_key = YAML::Any.new("dependencies")
    deps = yaml[deps_key]?.try(&.as_h) || {} of YAML::Any => YAML::Any

    dep = git_url_to_dependency(url)
    dep_name_key = YAML::Any.new(dep[:name])

    if deps.delete(dep_name_key)
        yaml[deps_key] = YAML::Any.new(deps)
        File.write(PKGFILE, YAML::Any.new(yaml).to_yaml)
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

def show_version
    print_info "sword v0.2.0"
end

def show_help
    print_title "sword"
    puts "usage:\n"
    puts "  sword get <package-url> [version]".colorize(:yellow).to_s + " - Add a dependency"
    puts "  sword rm <package-url>".colorize(:yellow).to_s + " - Remove a dependency"
    puts "  sword up".colorize(:yellow).to_s + " - Update and prune dependencies"
    puts "  sword b [build-args]".colorize(:yellow).to_s + " - Build project"
    puts "  sword search <query>".colorize(:yellow).to_s + " - Search for packages"
    puts "  sword deps".colorize(:yellow).to_s + " - Show dependency tree"
    puts "  sword init <name>".colorize(:yellow).to_s + " - Initialize a new project"
    puts "  sword clean".colorize(:yellow).to_s + " - Clean cache"
    puts "  sword version".colorize(:yellow).to_s + " - Show version"
    puts "  sword help".colorize(:yellow).to_s + " - Show this help"
end

# Main command processing
case ARGV[0]?
when "up"
    update_and_prune()
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
when "deps"
    show_dependency_tree()
when "init"
    if ARGV.size < 2
        print_error "Usage: sword init <name>"
        exit 1
    end
    init_project(ARGV[1])
when "clean"
    clean_cache()
when "version"
    show_version()
when "help", nil
    show_help()
else
    print_error "Unknown command: #{ARGV[0]}"
    show_help()
    exit 1
end
