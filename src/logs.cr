def print_title(title)
  puts "=== #{title} ===".colorize(:cyan)
end

def print_success(message)
  puts "✅ #{message}".colorize(:green)
end

def print_error(message)
  puts "❌ #{message}".colorize(:red)
end

def print_info(message)
  puts "ℹ️ #{message}".colorize(:blue)
end

def print_warning(message)
  puts "⚠️ #{message}".colorize(:yellow)
end
