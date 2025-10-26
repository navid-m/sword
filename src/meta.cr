def show_version
    print_info "sword " + Sword::VERSION
end

def show_about
    show_version
    puts "By Navid M. (c) 2025".colorize(:red)
    puts "https://github.com/navid-m".colorize(:red)
end

def show_help
    puts "usage: sword <command>\n\n"
    puts "  get|add <package-url> <optional: version>".colorize(:blue).to_s + " - Add a dependency"
    puts "  rm <package-url>".colorize(:blue).to_s + " - Remove a dependency"
    puts "  up".colorize(:blue).to_s + " - Update and prune dependencies"
    puts "  t <target-name> <source.cr>".colorize(:blue).to_s + " - Add build target to project"
    puts "  b <build-args>".colorize(:blue).to_s + " - Build project"
    puts "  br".colorize(:blue).to_s + " - Build project in release mode"
    puts "  bs".colorize(:blue).to_s + " - Build project statically linked"
    puts "  brs".colorize(:blue).to_s + " - Build project in release mode and statically linked"
    puts "  init <name>".colorize(:blue).to_s + " - Initialize a new project"
    puts "  i".colorize(:blue).to_s + " - Initialize minimal project (shards init)"
    puts "  il".colorize(:blue).to_s + " - Initialize library project (shards init --type lib)"
    puts "  c <source-file>".colorize(:blue).to_s + " - Compile a .cr to an executable"
    puts "  search <query>".colorize(:cyan).to_s + " - Search for packages"
    puts "  deps".colorize(:cyan).to_s + " - Show dependency tree"
    puts "  info <shard-name>".colorize(:cyan).to_s + " - Show information about a shard"
    puts "  clean".colorize(:red).to_s + " - Clean cache"
    puts "  version".colorize(:red).to_s + " - Show version"
    puts "  about".colorize(:red).to_s + " - Show about"
    puts "  help".colorize(:red).to_s + " - Show this help"
end
