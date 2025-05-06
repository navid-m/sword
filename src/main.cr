require "yaml"
require "uri"

def github_to_dependency(url : String) : NamedTuple(name: String, repo: String)
    uri = URI.parse(url)
    unless uri.host == "github.com"
        abort "non-gh url"
    end
    parts = uri.path.split("/").reject(&.empty?)
    if parts.size < 2
        abort "invalid git url format"
    end
    name = parts.last.downcase
    repo = "#{parts[0]}/#{parts[1]}"
    {name: name, repo: repo}
end

pkgfile = "shard.yml"

begin
    yaml_raw = YAML.parse(File.read(pkgfile))
rescue
    abort "no #{pkgfile} was found in the current directory"
end

yaml = yaml_raw.as_h
deps_key = YAML::Any.new("dependencies")
deps = yaml[deps_key]?.try(&.as_h) || {} of YAML::Any => YAML::Any

if ARGV.size != 2 || !(flag = ARGV[0]).in?({"-get", "-rm"})
    abort "usage: knife -get|-rm <package-url>"
end

flag = ARGV[0]
url = ARGV[1]
dep = github_to_dependency(url)
dep_name_key = YAML::Any.new(dep[:name])

if flag == "-get"
    dep_entry = {YAML::Any.new("github") => YAML::Any.new(dep[:repo])}
    deps[dep_name_key] = YAML::Any.new(dep_entry)
    yaml[deps_key] = YAML::Any.new(deps)
    File.write(pkgfile, YAML::Any.new(yaml).to_yaml)
    puts "✅ added dependency #{dep[:name]} from #{dep[:repo]}"
elsif flag == "-rm"
    if deps.delete(dep_name_key)
        yaml[deps_key] = YAML::Any.new(deps)
        File.write(pkgfile, YAML::Any.new(yaml).to_yaml)
        puts "🗑️ removed dependency #{dep[:name]}"
    else
        puts "dependency: #{dep[:name]} not found, nothing to remove."
    end
end
