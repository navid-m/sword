def extract_dependency(dependency : String) : Dependency | Nil
  repo_roots = [
    "https://github.com/",
    "http://github.com/",
    "http://gitlab.com/",
    "https://gitlab.com/",
  ]
  repo_roots.each do |repo_root|
    repo_url = dependency.downcase
    if (
         repo_url.includes? repo_root
       )
      puts repo_url, "contains", repo_root
      author_slash_library = repo_url.lchop(repo_root).split("/")
      return Dependency.new(
        source = determine_source(repo_root),
        author = author_slash_library[0],
        library = author_slash_library[1]
      )
    end
  end
  return nil
end

def determine_source(source : String) : String
  if source.includes?("github")
    "github"
  else
    "gitlab"
  end
end
