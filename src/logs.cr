def print_title(title)
    dash_line = "─" * 64
    puts dash_line
    puts "#{title}"
    puts dash_line + "\n\n"
end

def print_success(message)
    puts "[✓] #{message}".colorize(:green)
end

def print_error(message)
    puts "[x] #{message}".colorize(:red)
end

def print_info(message)
    puts "[i] #{message}".colorize(:blue)
end

def print_warning(message)
    puts "[!] #{message}".colorize(:yellow)
end
