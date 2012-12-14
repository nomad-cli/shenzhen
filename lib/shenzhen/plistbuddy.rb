module Shenzhen::PlistBuddy
  class << self
    def print(file, key)
      output = `/usr/libexec/PlistBuddy -c "Print :#{key}" "#{file}" 2> /dev/null`

      !output || output.empty? || /Does Not Exist/ === output ? nil : output.strip
    end
  end
end
