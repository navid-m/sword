def extract_dependency(dependency : String) : Dependency | Nil
  repo_url = dependency.downcase
  if (
       repo_url.includes? "https://github.com/"
     )
    author_slash_library = repo_url.lchop("https://github.com/").split("/")
    return Dependency.new(
      source = "github",
      author = author_slash_library[0],
      library = author_slash_library[1]
    )
  end
  return nil
end
