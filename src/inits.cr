def init_project(name : String)
    if Dir.exists?(name)
        print_error "Directory '#{name}' already exists"
        return
    end

    print_info "Initializing new project: #{name}"
    Dir.mkdir_p(name)

    %w(src spec).each do |dir|
        Dir.mkdir_p("#{name}/#{dir}")
    end
    File.write("#{name}/src/#{name}.cr", <<-CRYSTAL
    module #{name.camelcase}
      VERSION = "0.1.0"

      # TODO: Add your code here
    end
    CRYSTAL
    )
    File.write("#{name}/spec/spec_helper.cr", <<-CRYSTAL
    require "spec"
    require "../src/#{name}"
    CRYSTAL
    )

    File.write("#{name}/spec/#{name}_spec.cr", <<-CRYSTAL
    require "./spec_helper"
    describe #{name.camelcase} do
      # TODO: Add tests here
      it "works" do
        #{name.camelcase}.should be_truthy
      end
    end
    CRYSTAL
    )

    File.write("#{name}/shard.yml", <<-YAML
    name: #{name}
    version: 0.1.0

    authors:
      - Your Name <your.email@example.com>

    description: |
      A short description of #{name}

    crystal: ">= 1.0.0"

    development_dependencies:
      ameba:
        github: crystal-ameba/ameba

    license: MIT
    YAML
    )

    File.write("#{name}/.gitignore", <<-GITIGNORE
    /docs/
    /lib/
    /bin/
    /.shards/
    *.dwarf
    GITIGNORE
    )

    print_success "Project created in ./#{name}/"
    print_info "Run 'cd #{name} && sword build' to build your project"
end
