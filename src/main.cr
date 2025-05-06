require "yaml"
require "uri"

pkgfile         = "shard.yml"
SUPPORTED_HOSTS = {
    "github.com"   => "github",
    "gitlab.com"   => "gitlab",
    "codeberg.org" => "codeberg"
}

def git_url_to_dependency(url : String) : NamedTuple(name: String, repo: String, provider: String)
    uri = URI.parse(url)
    provider = SUPPORTED_HOSTS[uri.host]?
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


begin
    yaml_raw = YAML.parse(File.read(pkgfile))
rescue
    abort "No #{pkgfile} was found in the current directory."
end

yaml     = yaml_raw.as_h
deps_key = YAML::Any.new("dependencies")
deps     = yaml[deps_key]?.try(&.as_h) || {} of YAML::Any => YAML::Any

if ARGV.size != 2 || !(flag = ARGV[0]).in?({"-get", "-rm"})
    abort "usage: knife -get|-rm <package-url>"
end

flag = ARGV[0]
url  = ARGV[1]
dep  = git_url_to_dependency(url)
dep_name_key = YAML::Any.new(dep[:name])

if flag == "-get"
    dep_entry = {YAML::Any.new(dep[:provider]) => YAML::Any.new(dep[:repo])}
    deps[dep_name_key] = YAML::Any.new(dep_entry)
    yaml[deps_key] = YAML::Any.new(deps)
    File.write(pkgfile, YAML::Any.new(yaml).to_yaml)
    puts "✅ Added dependency #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}."
elsif flag == "-rm"
    if deps.delete(dep_name_key)
        yaml[deps_key] = YAML::Any.new(deps)
        File.write(pkgfile, YAML::Any.new(yaml).to_yaml)
        puts "🗑️ Removed dependency #{dep[:name]}."
    else
        puts "Dependency: #{dep[:name]} not found, nothing to remove."
    end
end
