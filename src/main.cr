require "../src/logs"
require "../src/deps"

PKGFILE  = "shard.yml"
CACHEDIR = File.join(get_home_directory, ".sword", "cache")
HOSTS    = {
    "github.com"   => "github",
    "gitlab.com"   => "gitlab",
    "codeberg.org" => "codeberg",
}

FileUtils.mkdir_p(CACHEDIR) unless Dir.exists?(CACHEDIR)

case ARGV[0]?
when "tidy"
    if !prune()
        print_error "Shards executable was not available, nothing tidied."
    end
when "b"
    build_args = ARGV.size > 1 ? ARGV[1..] : [] of String
    build_project(build_args)
when "get"
    if ARGV.size < 2
        print_error "Usage: sword get <package-url> [version]"
        exit 1
    end
    version = ARGV[2]? if ARGV.size > 2
    add_dependency(ARGV[1], version)
when "rm"
    if ARGV.size < 2
        print_error "Usage: sword rm <package-url>"
        exit 1
    end
    remove_dependency(ARGV[1])
when "search"
    if ARGV.size < 2
        print_error "Usage: sword search <query>"
        exit 1
    end
    search_packages(ARGV[1])
when "c"
    if ARGV.size < 2
        print_error "Usage: sword c <file.cr>"
        exit 1
    end
    compile_single(ARGV[1])
when "init"
    if ARGV.size < 2
        print_error "Usage: sword init <name>"
        exit 1
    end
    init_project(ARGV[1])
when "info"
    if ARGV.size < 2
        print_error "Usage: sword info <package-url>"
        exit 1
    end
    fetch_shard_info(ARGV[1])
when "t"
    if ARGV.size < 3
        print_error "Usage: sword t <target_name> <source_file.cr>"
        exit 1
    end
    add_target_to_shard(ARGV[1], ARGV[2])
when "up"
    update_and_prune
when "br"
    build_project_release
when "bs"
    build_project_static
when "clean"
    clean_cache
when "version"
    show_version
when "deps"
    show_dependency_tree
when "about"
    show_about
when "help", nil
    show_help
else
    print_error "Unknown command: #{ARGV[0]}"
    show_help
    exit 1
end
