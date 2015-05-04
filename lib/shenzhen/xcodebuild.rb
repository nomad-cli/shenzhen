require 'ostruct'

module Shenzhen::XcodeBuild
  class Info < OpenStruct; end
  class Settings < OpenStruct
    include Enumerable

    def initialize(hash = {})
      super
      self.targets = hash.keys
    end

    def members
      self.targets
    end

    def each
      members.each do |target|
        yield target, send(target)
      end

      self
    end
  end

  class Error < StandardError; end
  class NilOutputError < Error; end

  class << self
    def info(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      output = `xcrun xcodebuild -list #{(args + args_from_options(options)).join(" ")} 2>&1`

      raise Error.new $1 if /^xcodebuild\: error\: (.+)$/ === output

      return nil unless /\S/ === output

      lines = output.split(/\n/)
      info, group = {}, nil

      info[:project] = lines.shift.match(/\"(.+)\"\:/)[1] rescue nil

      lines.each do |line|
        if /\:$/ === line
          group = line.strip[0...-1].downcase.gsub(/\s+/, '_')
          info[group] = []
          next
        end

        unless group.nil? or /\.$/ === line
          info[group] << line.strip
        end
      end

      info.each do |group, values|
        next unless Array === values
        values.delete("") and values.uniq!
      end

      Info.new(info)
    end

    def settings(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      output = `xcrun xcodebuild #{(args + args_from_options(options)).join(" ")} -showBuildSettings 2> /dev/null`

      return nil unless /\S/ === output

      raise Error.new $1 if /^xcodebuild\: error\: (.+)$/ === output

      lines = output.split(/\n/)

      settings, target = {}, nil
      lines.each do |line|
        case line
        when /Build settings for action build and target \"?([^":]+)/
          target = $1
          settings[target] = {}
        else
          key, value = line.split(/\=/).collect(&:strip)
          settings[target][key] = value if target
        end
      end

      Settings.new(settings)
    end

    def version
      output = `xcrun xcodebuild -version`
      output.scan(/([\d+\.?]+)/).flatten.first rescue nil
    end

    private

    def args_from_options(options = {})
      options.reject{|key, value| value.nil?}.collect{|key, value| "-#{key} '#{value}'"}
    end
  end
end
