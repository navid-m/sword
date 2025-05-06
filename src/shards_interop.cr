def prune : Bool
    if shards_available?
        print_info "Pruning dependencies..."
        system("shards prune")
        print_success "Dependencies cleaned."
        return true
    end
    false
end

def update_and_prune
    if shards_available?
        print_info "Updating dependencies..."
        prune
        if !system("shards update")
            print_error "Dependencies failed to update."
        else
            print_success "Dependencies updated."
        end
    else
        print_error "shards executable not available in path, skipping update and prune."
    end
end

def build_project(args : Array(String) = [] of String)
    if shards_available?
        build_command = ["shards", "build"]
        build_command.concat(args)
        print_info "Building project with: #{build_command.join(" ")}"
        system(build_command.join(" "))
    else
        print_error "shards executable not available in path, skipping build."
    end
end

def compile_single(source_file : String)
    if shards_available?
        build_command = ["crystal", "build"]
        begin
            if source_file.includes?(".cr")
                build_command << source_file
            else
                build_command << source_file + ".cr"
            end
        rescue ex
            abort "Could not compile #{source_file}: #{ex.message}"
        end
    end
end

def build_project_release
    build_project(["--release"])
end

def build_project_static
    build_project(["--static"])
end

def shards_available?
    {% if flag?(:win32) || flag?(:windows) %}
        process = Process.new(
            "where", ["shards"], output: Process::Redirect::Pipe, error: Process::Redirect::Pipe
        )
        output = process.output.gets_to_end
        status = process.wait
        status.success? && !output.strip.empty?
    {% else %}
        process = Process.new(
            "which", ["shards"], shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe
        )
        output = process.output.gets_to_end
        status = process.wait
        status.success? && !output.strip.empty?
    {% end %}
end
