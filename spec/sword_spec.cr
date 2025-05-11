require "spec"
require "yaml"
require "file_utils"
require "../src/logs"
require "../src/dirs"
require "../src/inits"
require "../src/meta"
require "../src/shards_interop"
require "../src/sword"

describe "Sword" do
    temp_dir = File.join(Dir.tempdir, "sword_test_#{Random.new.hex(8)}")

    before_each do
        FileUtils.mkdir_p(temp_dir)
        Dir.cd(temp_dir)
    end

    after_each do
        Dir.cd("/")
        FileUtils.rm_rf(temp_dir)
    end

    describe "#read_shard_yml" do
        it "reads shard.yml file" do
            File.write("shard.yml", "name: test\nversion: 0.1.0\n")
            (read_shard_yml).should eq(["name: test", "version: 0.1.0"])
            File.file?("shard.yml").should be_true
        end
    end

    describe "#load_shard_yml" do
        it "loads YAML from shard.yml" do
            File.write("shard.yml", "name: test\nversion: 0.1.0\n")
            yaml = load_shard_yml
            yaml["name"].as_s.should eq("test")
            yaml["version"].as_s.should eq("0.1.0")
        end
    end

    describe "#git_url_to_dependency" do
        it "parses GitHub URL" do
            result = git_url_to_dependency("https://github.com/crystal-lang/crystal")
            result[:name].should eq("crystal")
            result[:repo].should eq("crystal-lang/crystal")
            result[:provider].should eq("github")
        end

        it "parses GitLab URL" do
            result = git_url_to_dependency("https://gitlab.com/example/project")
            result[:name].should eq("project")
            result[:repo].should eq("example/project")
            result[:provider].should eq("gitlab")
        end

        it "parses Codeberg URL" do
            result = git_url_to_dependency("https://codeberg.org/user/repo")
            result[:name].should eq("repo")
            result[:repo].should eq("user/repo")
            result[:provider].should eq("codeberg")
        end
    end

    describe "#add_dependency" do
        before_each do
            File.write("shard.yml", <<-YAML
        name: test
        version: 0.1.0
        YAML
            )
        end

        it "adds a dependency to empty dependencies section" do
            add_dependency("https://github.com/kemalcr/kemal")
            shard_content = File.read("shard.yml")
            shard_content.should contain("dependencies:")
            shard_content.should contain("kemal:")
            shard_content.should contain("github: kemalcr/kemal")
        end

        it "adds a dependency with version" do
            add_dependency("https://github.com/kemalcr/kemal", "0.27.0")
            shard_content = File.read("shard.yml")
            shard_content.should contain("version: 0.27.0")
        end

        it "preserves existing dependencies" do
            File.write("shard.yml", <<-YAML
        name: test
        version: 0.1.0
        dependencies:
           markd:
              github: icyleaf/markd
        YAML
            )
            add_dependency("https://github.com/kemalcr/kemal")
            shard_content = File.read("shard.yml")
            shard_content.should contain("markd:")
            shard_content.should contain("kemal:")
        end

        it "preserves existing indentation patterns" do
            File.write("shard.yml", <<-YAML
        name: test
        version: 0.1.0
        dependencies:
           markd:
              github: icyleaf/markd
        YAML
            )
            add_dependency("https://github.com/kemalcr/kemal")
            lines = File.read_lines("shard.yml")

            markd_line = lines.find { |line| line.includes?("markd:") }
            kemal_line = lines.find { |line| line.includes?("kemal:") }

            markd_indent = markd_line.not_nil!.index("markd").not_nil!
            kemal_indent = kemal_line.not_nil!.index("kemal").not_nil!
            markd_indent.should eq(kemal_indent)

            markd_github_line = lines.find { |line| line.includes?("github: icyleaf/markd") }
            kemal_github_line = lines.find { |line| line.includes?("github: kemalcr/kemal") }

            markd_github_indent = markd_github_line.not_nil!.index("github").not_nil!
            kemal_github_indent = kemal_github_line.not_nil!.index("github").not_nil!
            markd_github_indent.should eq(kemal_github_indent)
        end

        it "properly handles different indentation patterns" do
            File.write("shard.yml", <<-YAML
        name: test
        version: 0.1.0
        dependencies:
          markd:
            github: icyleaf/markd
        YAML
            )
            add_dependency("https://github.com/kemalcr/kemal")
            lines = File.read_lines("shard.yml")

            markd_line = lines.find { |line| line.includes?("markd:") }
            kemal_line = lines.find { |line| line.includes?("kemal:") }

            markd_indent = markd_line.not_nil!.index("markd").not_nil!
            kemal_indent = kemal_line.not_nil!.index("kemal").not_nil!
            markd_indent.should eq(kemal_indent)

            markd_github_line = lines.find { |line| line.includes?("github: icyleaf/markd") }
            kemal_github_line = lines.find { |line| line.includes?("github: kemalcr/kemal") }

            markd_github_indent = markd_github_line.not_nil!.index("github").not_nil!
            kemal_github_indent = kemal_github_line.not_nil!.index("github").not_nil!
            markd_github_indent.should eq(kemal_github_indent)
        end

        it "updates an existing dependency" do
            File.write("shard.yml", <<-YAML
        name: test
        version: 0.1.0
        dependencies:
           kemal:
              github: kemalcr/kemal
              version: 0.26.0
        YAML
            )
            add_dependency("https://github.com/kemalcr/kemal", "0.27.0")
            shard_content = File.read("shard.yml")
            shard_content.should contain("version: 0.27.0")
            shard_content.should_not contain("version: 0.26.0")
        end
    end

    describe "#remove_dependency" do
        before_each do
            File.write("shard.yml", <<-YAML
        name: test
        version: 0.1.0
        dependencies:
           kemal:
              github: kemalcr/kemal
           markd:
              github: icyleaf/markd
        YAML
            )
        end

        it "removes a dependency" do
            remove_dependency("https://github.com/kemalcr/kemal")
            shard_content = File.read("shard.yml")
            shard_content.should_not contain("kemal:")
            shard_content.should contain("markd:")
        end

        it "removes the dependencies section when removing the last dependency" do
            remove_dependency("https://github.com/kemalcr/kemal")
            remove_dependency("https://github.com/icyleaf/markd")
            shard_content = File.read("shard.yml")
            shard_content.should_not contain("dependencies:")
        end
    end

    describe "#add_target_to_shard" do
        before_each do
            File.write("shard.yml", <<-YAML
        name: test
        version: 0.1.0
        YAML
            )
        end

        it "adds a target" do
            add_target_to_shard("cli", "main.cr")
            shard_content = File.read("shard.yml")
            shard_content.should contain("targets:")
            shard_content.should contain("cli:")
            shard_content.should contain("main: src/main.cr")
        end

        it "adds multiple targets" do
            add_target_to_shard("cli", "main.cr")
            add_target_to_shard("web", "web.cr")

            shard_content = File.read("shard.yml")
            shard_content.should contain("cli:")
            shard_content.should contain("main: src/main.cr")
            shard_content.should contain("web:")
            shard_content.should contain("main: src/web.cr")
        end

        it "preserves existing targets" do
            File.write("shard.yml", <<-YAML
        name: test
        version: 0.1.0
        targets:
          cli:
            main: src/main.cr
        YAML
            )

            add_target_to_shard("web", "web.cr")

            shard_content = File.read("shard.yml")
            shard_content.should contain("cli:")
            shard_content.should contain("main: src/main.cr")
            shard_content.should contain("web:")
            shard_content.should contain("main: src/web.cr")
        end
    end
end
