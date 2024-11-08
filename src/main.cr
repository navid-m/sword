require "yaml"
require "../src/mods"

if ARGV.size > 0
  dep = extract_dependency(ARGV[0]).as(Dependency)
  begin
    yaml = YAML.parse(File.read("shard.yml")).as_h
    yaml[YAML::Any.new("dependencies")] = YAML::Any.new("fuck") # Error: expected argument #1 to 'Hash(YAML::Any, YAML::Any)#[]=' to be YAML::Any, not String
    puts yaml
  rescue e : Exception
    puts "Something went wrong: ", e
  end
end

def extract_dependency(dependency : String)
  Dependency
  repoUrl = dependency.downcase
  if (
       repoUrl.includes? "https://github.com/"
     )
    repoUrl = repoUrl.lchop("https://github.com/")
    return Dependency.new(
      source = "github",
      authorSlashLibrary = repoUrl
    )
  end
end
