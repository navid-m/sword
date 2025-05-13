require "json"

def fetch_shard_info(url : String)
    dep = git_url_to_dependency(url)
    print_info "Fetching information for #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}"

    case dep[:provider]
    when "github"
        fetch_github_info(dep[:repo], dep[:name])
    when "gitlab"
        fetch_gitlab_info(dep[:repo], dep[:name])
    when "codeberg"
        fetch_codeberg_info(dep[:repo], dep[:name])
    else
        print_error "Unsupported provider: #{dep[:provider]}"
    end
end

def search_packages(query : String)
    print_info "Searching for packages matching '#{query}'..."

    begin
        response = HTTP::Client.get(
            "https://api.github.com/search/repositories?q=#{URI.encode_www_form(query)}+language:crystal&sort=stars&order=desc"
        )

        if response.status_code == 200
            results = JSON.parse(response.body)

            if results["items"].as_a.size > 0
                print_title "Search Results"

                results["items"].as_a[0..9].each_with_index do |item, index|
                    repo_name = item["full_name"].as_s
                    description = item["description"].as_s? || "No description"
                    stars = item["stargazers_count"].as_i
                    url = item["html_url"].as_s

                    puts "#{index + 1}. #{repo_name.colorize(:green)} (#{stars})"
                    puts "   #{description}"
                    puts "   #{url.colorize(:blue)}"
                    puts ""
                end

                print_info "To add a package: sword get [URL]"
            else
                print_warning "No packages found matching '#{query}'"
            end
        else
            print_error "Failed to search packages: #{response.status_code}"
        end
    rescue ex
        print_error "Error searching packages: #{ex.message}"
    end
end

def fetch_github_info(repo : String, name : String)
    begin
        repo_response = HTTP::Client.get(
            "https://api.github.com/repos/#{repo}",
            headers: HTTP::Headers{"Accept" => "application/vnd.github.v3+json"}
        )

        if repo_response.status_code != 200
            print_error "Failed to fetch repository information: HTTP #{repo_response.status_code}"
            return
        end

        repo_data = JSON.parse(repo_response.body)
        content_response = HTTP::Client.get(
            "https://api.github.com/repos/#{repo}/contents/shard.yml",
            headers: HTTP::Headers{"Accept" => "application/vnd.github.v3+json"}
        )

        shard_data = {} of String => String
        if content_response.status_code == 200
            content = JSON.parse(content_response.body)
            if content["content"]?
                begin
                    decoded = Base64.decode_string(content["content"].as_s)
                    yaml = YAML.parse(decoded)

                    shard_data["version"] = yaml["version"]?.try(&.as_s) || "Unknown"
                    shard_data["crystal"] = yaml["crystal"]?.try(&.as_s) || "Any"
                    shard_data["license"] = yaml["license"]?.try(&.as_s) || "Unknown"
                    shard_data["description"] = yaml["description"]?.try(&.as_s) || "No description"
                rescue
                  # Continue...
                end
            end
        end

        puts "Name:         #{name}".colorize(:green)
        puts "Repository:   #{repo_data["html_url"].as_s}"
        puts "Description:  #{repo_data["description"].as_s? || "No description"}"
        puts "Stars:        #{repo_data["stargazers_count"].as_i}"
        puts "Forks:        #{repo_data["forks_count"].as_i}"
        puts "Open Issues:  #{repo_data["open_issues_count"].as_i}"
        puts "Last Updated: #{repo_data["updated_at"].as_s}"
        puts "License:      #{shard_data["license"]? || repo_data["license"].try(&.["name"].as_s?) || "Unknown"}"

        if shard_data["version"]?
            puts "Version:      #{shard_data["version"]}"
        end

        if shard_data["crystal"]?
            puts "Crystal:      #{shard_data["crystal"]}"
        end

        puts "\nTo add this package:"
        puts "  sword get #{repo_data["html_url"].as_s}".colorize(:yellow)
    rescue ex
        print_error "Error fetching information: #{ex.message}"
    end
end

def fetch_gitlab_info(repo : String, name : String)
    begin
        repo_encoded = URI.encode_www_form(repo)
        repo_response = HTTP::Client.get(
            "https://gitlab.com/api/v4/projects/#{repo_encoded}"
        )

        if repo_response.status_code != 200
            print_error "Failed to fetch repository information: HTTP #{repo_response.status_code}"
            return
        end

        repo_data = JSON.parse(repo_response.body)
        print_title "#{name} Information"
        puts "Name:         #{name}".colorize(:green)
        puts "Repository:   #{repo_data["web_url"].as_s}"
        puts "Description:  #{repo_data["description"].as_s? || "No description"}"
        puts "Stars:        #{repo_data["star_count"].as_i}"
        puts "Forks:        #{repo_data["forks_count"].as_i}"
        puts "Open Issues:  #{repo_data["open_issues_count"].as_i}"
        puts "Last Updated: #{repo_data["last_activity_at"].as_s}"
        puts "License:      #{repo_data["license"].try(&.["name"].as_s?) || "Unknown"}"

        puts "\nTo add this package:"
        puts "  sword get #{repo_data["web_url"].as_s}".colorize(:yellow)
    rescue ex
        print_error "Error fetching information: #{ex.message}"
    end
end

def fetch_codeberg_info(repo : String, name : String)
    begin
        repo_encoded = URI.encode_www_form(repo)
        repo_response = HTTP::Client.get(
            "https://codeberg.org/api/v1/repos/#{repo_encoded}"
        )

        if repo_response.status_code != 200
            print_error "Failed to fetch repository information: HTTP #{repo_response.status_code}"
            return
        end

        repo_data = JSON.parse(repo_response.body)
        print_title "#{name} Information"

        puts "Name:         #{name}".colorize(:green)
        puts "Repository:   #{repo_data["html_url"].as_s}"
        puts "Description:  #{repo_data["description"].as_s? || "No description"}"
        puts "Stars:        #{repo_data["stars_count"].as_i}"
        puts "Forks:        #{repo_data["forks_count"].as_i}"
        puts "Open Issues:  #{repo_data["open_issues_count"].as_i}"
        puts "Last Updated: #{repo_data["updated_at"].as_s}"

        puts "\nTo add this package:"
        puts "  sword get #{repo_data["html_url"].as_s}".colorize(:yellow)
    rescue ex
        print_error "Error fetching information: #{ex.message}"
    end
end
