module Shenzhen::Agvtool
  class << self
    def what_version
      output = `agvtool what-version -terse`
      output.length > 0 ? output : nil
    end
    
    alias :vers :what_version
    
    def what_marketing_version
      output = `agvtool what-marketing-version -terse`
      output.scan(/\=(.+)$/).flatten.first
    end
    
    alias :mvers :what_marketing_version
  end
end
