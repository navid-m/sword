require "yaml"
require "../src/mods"
require "../src/deps"

if ARGV.size > 0
  dep = extract_dependency(ARGV[0]).as(Dependency | Nil)
  if dep
    begin
      target_file_name = "test.yml"
      yaml = YAML.parse(File.read(target_file_name)).as_h
      dependencies = yaml[YAML::Any.new("dependencies")].as_h? || Hash(YAML::Any, YAML::Any).new
      inner_hash = Hash(YAML::Any, YAML::Any).new

      inner_hash[YAML::Any.new(dep.source)] = YAML::Any.new(dep.author + "/" + dep.library)
      dependencies[YAML::Any.new(dep.library)] = YAML::Any.new(inner_hash)
      yaml[YAML::Any.new("dependencies")] = YAML::Any.new(dependencies)

      File.open(target_file_name, "w") do |shard_yml_file|
        shard_yml_file.print yaml.to_yaml.to_s.lchop("---")
      end
    rescue e : Exception
      puts "Something went wrong: ", e
    end
  end
end
