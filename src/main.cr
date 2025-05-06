require "yaml"
require "uri"

pkgfile = "shard.yml"
HOSTS   = {
    "github.com"   => "github",
    "gitlab.com"   => "gitlab",
    "codeberg.org" => "codeberg"
}

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

def prune : Bool
    if shards_available?
        system("shards prune")
        puts "Dependencies cleaned."
        return true
    end
    false
end

def update_and_prune
    if shards_available?
        prune()
        system("shards update")
    else
        puts "shards executable not available in path, skipping update and prune."
    end
end

def build_project(args : Array(String) = [] of String)
    if shards_available?
        build_command = ["shards", "build"]
        build_command.concat(args)
        system(build_command.join(" "))
    else
        puts "shards executable not available in path, skipping build."
    end
end

def shards_available?
    {% if flag?(:win32) || flag?(:windows) %}
        process = Process.new(
            "where", ["shards"], output: Process::Redirect::Pipe, error: Process::Redirect::Pipe
        )
        output = process.output.gets_to_end
        status = process.wait
        status.success? && !output.strip.empty?
    {% else %}
        process = Process.new(
            "which", ["shards"], shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe
        )
        output = process.output.gets_to_end
        status = process.wait
        status.success? && !output.strip.empty?
    {% end %}
end

if ARGV.size >= 1
    case ARGV[0]
    when "up"
        update_and_prune()
        abort
    when "tidy"
        if !prune()
            puts "Shards executable was not available, nothing tidied."
        end
        abort
    when "b"
        build_args = ARGV.size > 1 ? ARGV[1..-1] : [] of String
        build_project(build_args)
        abort
    end
end

if ARGV.size != 2 || !(flag = ARGV[0]).in?({"get", "rm"})
    abort "usage: sword get|rm|up|b <package-url>\n       sword b [build-args]"
end

begin
    yaml_raw = YAML.parse(File.read(pkgfile))
rescue
    abort "No #{pkgfile} was found in the current directory."
end

yaml     = yaml_raw.as_h
deps_key = YAML::Any.new("dependencies")
deps     = yaml[deps_key]?.try(&.as_h) || {} of YAML::Any => YAML::Any
flag     = ARGV[0]
url      = ARGV[1]
dep      = git_url_to_dependency(url)
ran      = false
dep_name_key = YAML::Any.new(dep[:name])

if flag == "get"
    ran = true
    dep_entry = {YAML::Any.new(dep[:provider]) => YAML::Any.new(dep[:repo])}
    deps[dep_name_key] = YAML::Any.new(dep_entry)
    yaml[deps_key] = YAML::Any.new(deps)
    File.write(pkgfile, YAML::Any.new(yaml).to_yaml)
    puts "✅ Added dependency #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}."
elsif flag == "rm"
    ran = true
    if deps.delete(dep_name_key)
        yaml[deps_key] = YAML::Any.new(deps)
        File.write(pkgfile, YAML::Any.new(yaml).to_yaml)
        puts "🗑️ Removed dependency #{dep[:name]}."
    else
        puts "Dependency: #{dep[:name]} not found, nothing to remove."
    end
end

if ran && shards_available?
    update_and_prune
end
