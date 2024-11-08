require "yaml"
require "../src/mods"
require "../src/deps"

if ARGV.size > 0
  dep = extract_dependency(ARGV[0]).as(Dependency)
  begin
    yaml = YAML.parse(File.read("test.yml")).as_h
    dependencies = yaml[YAML::Any.new("dependencies")].as_h? || Hash(YAML::Any, YAML::Any).new
    inner_hash = Hash(YAML::Any, YAML::Any).new

    inner_hash[YAML::Any.new("github")] = YAML::Any.new(dep.author + "/" + dep.library)
    dependencies[YAML::Any.new(dep.library)] = YAML::Any.new(inner_hash)
    yaml[YAML::Any.new("dependencies")] = YAML::Any.new(dependencies)

    puts yaml.to_yaml
  rescue e : Exception
    puts "Something went wrong: ", e
  end
end
