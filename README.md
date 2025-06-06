# Sword

CLI for rapid management of Crystal projects.

Navigate to the directory containing shards.yml and run any of these:

-  `sword get <package-url> [optional: version]` — Add a dependency
-  `sword rm <package-url>` — Remove a dependency
-  `sword up` — Update and prune dependencies
-  `sword b <build-args>` — Build the project
-  `sword t <target-name> <source-file.cr>` — Add a target to the project
-  `sword br` — Build the project in release mode
-  `sword bs` — Build the project with static linking
-  `sword init <name>` — Initialize a new project
-  `sword c <source-file>` — Compile a `.cr` file into an executable
-  `sword search <query>` — Search for packages
-  `sword deps` — Show the dependency tree
-  `sword info <shard-name>` — Show shard information
-  `sword clean` — Clean cache
-  `sword version` — Show the current version
-  `sword about` — About the tool
-  `sword help` — Display help

## License

GPL v3

---
