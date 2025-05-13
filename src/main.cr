require "yaml"
require "uri"
require "json"
require "http/client"
require "colorize"
require "file_utils"
require "../src/logs"
require "../src/dirs"
require "../src/infos"
require "../src/inits"
require "../src/meta"
require "../src/shards_interop"

PKGFILE  = "shard.yml"
CACHEDIR = File.join(get_home_directory, ".sword", "cache")
HOSTS    = {
    "github.com"   => "github",
    "gitlab.com"   => "gitlab",
    "codeberg.org" => "codeberg",
}

FileUtils.mkdir_p(CACHEDIR) unless Dir.exists?(CACHEDIR)

def add_target_to_shard(target_name : String, source_file : String)
    lines = read_shard_yml
    targets_index = -1
    targets_indentation = ""

    lines.each_with_index do |line, index|
        if line =~ /^(\s*)targets\s*:/
            targets_index = index
            targets_indentation = $1
            break
        end
    end

    if targets_index == -1
        lines << "" if lines.last != ""
        lines << "targets:"
        targets_index = lines.size - 1
        targets_indentation = ""
    end

    target_indentation = "#{targets_indentation}  "
    main_indentation = "#{targets_indentation}    "
    target_entry = [
        "#{target_indentation}#{target_name}:",
        "#{main_indentation}main: src/#{source_file}",
    ]

    existing_target_index = lines.index { |line| line =~ /^\s*#{Regex.escape(target_name)}\s*:/ }
    if existing_target_index
        print_warning "Target '#{target_name}' already exists in shard.yml."
        return
    end

    insert_index = targets_index + 1
    while insert_index < lines.size &&
          (lines[insert_index].empty? || lines[insert_index].starts_with?("#") || lines[insert_index] =~ /^\s+/)
        insert_index += 1
    end

    target_entry.each_with_index do |line, idx|
        lines.insert(insert_index + idx, line)
    end

    write_shard_yml(lines)
    print_success "Target '#{target_name}' added with main: src/#{source_file}"
end

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
    content = lines.join("\n")
    content += "\r" unless content.ends_with?("\r")
    File.write(PKGFILE, content)
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
    lines = read_shard_yml
    dependencies_index = -1
    dependencies_indentation = ""

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

    existing_dep_indentation = ""
    (dependencies_index + 1).upto(lines.size - 1) do |i|
        break if i >= lines.size || (lines[i] =~ /^\S/ && !lines[i].starts_with?("#"))
        if lines[i] =~ /^(\s+)\S+\s*:/
            existing_dep_indentation = $1
            break
        end
    end

    dep_indentation = existing_dep_indentation.empty? ? "#{dependencies_indentation}   " : existing_dep_indentation

    existing_prop_indentation = ""
    (dependencies_index + 1).upto(lines.size - 1) do |i|
        break if i >= lines.size || (lines[i] =~ /^\S/ && !lines[i].starts_with?("#"))
        if lines[i] =~ /^(\s+)\S+\s*:/ && lines[i + 1]? && lines[i + 1] =~ /^(\s+)\S+:/
            existing_prop_indentation = $1
            break
        end
    end

    prop_indentation = existing_prop_indentation.empty? ? "#{dep_indentation}   " : existing_prop_indentation

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
when "t"
    if ARGV.size < 3
        print_error "Usage: sword t <target_name> <source_file.cr>"
        exit 1
    end
    add_target_to_shard(ARGV[1], ARGV[2])
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
