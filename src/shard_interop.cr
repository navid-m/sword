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
        prune()
        system("shards update")
        print_success "Dependencies updated."
    else
        print_error "shards executable not available in path, skipping update and prune."
    end
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
