def show_version
    print_info "sword v0.2.0\n(c) Navid M 2025\ngithub.com/navid-m\ngitlab.com/navid-m"
end

def show_help
    print_title "sword"
    puts "usage:\n"
    puts "  sword get <package-url> [version]".colorize(:yellow).to_s + " - Add a dependency"
    puts "  sword rm <package-url>".colorize(:yellow).to_s + " - Remove a dependency"
    puts "  sword up".colorize(:yellow).to_s + " - Update and prune dependencies"
    puts "  sword b [build-args]".colorize(:yellow).to_s + " - Build project"
    puts "  sword c <source-file>".colorize(:yellow).to_s + " - Compile a .cr to an executable"
    puts "  sword br".colorize(:yellow).to_s + " - Build project in release mode"
    puts "  sword bs".colorize(:yellow).to_s + " - Build project statically linked"
    puts "  sword search <query>".colorize(:yellow).to_s + " - Search for packages"
    puts "  sword deps".colorize(:yellow).to_s + " - Show dependency tree"
    puts "  sword init <name>".colorize(:yellow).to_s + " - Initialize a new project"
    puts "  sword info <shard-name>".colorize(:yellow).to_s + " - Show information about a shard"
    puts "  sword clean".colorize(:yellow).to_s + " - Clean cache"
    puts "  sword version".colorize(:yellow).to_s + " - Show version"
    puts "  sword help".colorize(:yellow).to_s + " - Show this help"
end
