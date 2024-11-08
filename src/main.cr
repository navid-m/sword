require "yaml"

record Dependency,
  source : String,
  authorSlashLibrary : String

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

if ARGV.size > 0
  puts extract_dependency(ARGV[0])
end

begin
  yaml = File.open("shard.yml") do |file|
    x = YAML.parse(file)
    puts x["name"]
  end
rescue e : Exception
  puts "Something went wrong: ", e
end
