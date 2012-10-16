module Shenzhen
  class Config
    FILE_PATH = File.join(ENV['PWD'], '.shenzhen')

    def self.[](key)
      new[key]
    end

    def initialize
      @settings = load_settings
    end

    def [](key)
      @settings[key]
    end

    private

    def load_settings
      if File.exists?(FILE_PATH)
        read_from_config_file
      else
        {}
      end
    end

    def read_from_config_file
      lines = File.read(FILE_PATH).split("\n")
      lines.inject({}) do |memo, line|
        if line =~ /\A([A-Za-z_0-9]+)=(.*)\z/
          memo[$1] = $2
        end

        memo
      end
    end
  end
end
