def get_home_directory
    case
    when ENV.has_key?("HOME")
        ENV["HOME"]
    when ENV.has_key?("USERPROFILE")
        ENV["USERPROFILE"]
    else
        if ENV.has_key?("HOMEDRIVE") && ENV.has_key?("HOMEPATH")
            "#{ENV["HOMEDRIVE"]}#{ENV["HOMEPATH"]}"
        else
            raise "Could not determine home directory"
        end
    end
end
