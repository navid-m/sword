require "yaml"
require "../src/mods"

if ARGV.size > 0
  dep = extract_dependency(ARGV[0]).as(Dependency)
  begin
    yaml = YAML.parse(File.read("shard.yml")).as_h
    hash = Hash(YAML::Any, YAML::Any).new
    inner_hash = Hash(YAML::Any, YAML::Any).new

    inner_hash[YAML::Any.new("github")] = YAML::Any.new(dep.library)
    hash[YAML::Any.new(dep.author)] = YAML::Any.new(inner_hash)
    yaml[YAML::Any.new("dependencies")] = YAML::Any.new(hash)
    puts yaml.to_yaml
  rescue e : Exception
    puts "Something went wrong: ", e
  end
end

def extract_dependency(dependency : String) : Dependency | Nil
  repo_url = dependency.downcase
  if (
       repo_url.includes? "https://github.com/"
     )
    author_slash_library = repo_url.lchop("https://github.com/").split("/")
    return Dependency.new(
      source = "github",
      author = author_slash_library[0],
      library = author_slash_library[1]
    )
  end
  return nil
end
