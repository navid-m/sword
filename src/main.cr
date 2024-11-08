require "yaml"
require "../src/mods"

if ARGV.size > 0
  puts extract_dependency(ARGV[0])
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

begin
  yaml = File.open("shard.yml") do |file|
    x = YAML.parse(file)
    puts x
  end
rescue e : Exception
  puts "Something went wrong: ", e
end
