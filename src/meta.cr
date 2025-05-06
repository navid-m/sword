def show_version
    print_info "sword v0.2.0"
end

def show_about
    show_version
    puts "©️ Navid M 2025".colorize(:red)
    puts "©️ https://github.com/navid-m".colorize(:red)
end

def show_help
    print_title "sword - usage"
    puts "  sword get <package-url> <optional: version>".colorize(:blue).to_s + " - Add a dependency"
    puts "  sword rm <package-url>".colorize(:blue).to_s + " - Remove a dependency"
    puts "  sword up".colorize(:blue).to_s + " - Update and prune dependencies"
    puts "  sword b <build-args>".colorize(:blue).to_s + " - Build project"
    puts "  sword br".colorize(:blue).to_s + " - Build project in release mode"
    puts "  sword bs".colorize(:blue).to_s + " - Build project statically linked"
    puts "  sword init <name>".colorize(:blue).to_s + " - Initialize a new project"
    puts "  sword c <source-file>".colorize(:blue).to_s + " - Compile a .cr to an executable"
    puts "  sword search <query>".colorize(:cyan).to_s + " - Search for packages"
    puts "  sword deps".colorize(:cyan).to_s + " - Show dependency tree"
    puts "  sword info <shard-name>".colorize(:cyan).to_s + " - Show information about a shard"
    puts "  sword clean".colorize(:red).to_s + " - Clean cache"
    puts "  sword version".colorize(:red).to_s + " - Show version"
    puts "  sword about".colorize(:red).to_s + " - Show about"
    puts "  sword help".colorize(:red).to_s + " - Show this help"
end
