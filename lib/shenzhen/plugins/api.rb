require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module API
    class Client
      def initialize(host, username, password, path)
        @host, @username, @password, @path = host, username, password, path
        @connection = Faraday.new(:url => @host) do |builder|
          builder.request :multipart
          builder.request :json
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
        
        @connection.basic_auth(@username, @password) if @username and @password
      end

      def upload_build(ipa, options)
        options.update({
          :ipa => Faraday::UploadIO.new(ipa, 'application/octet-stream')
        })

        if dsym_filename = options.delete(:dsym_filename)
          options[:dsym] = Faraday::UploadIO.new(dsym_filename, 'application/octet-stream')
        end

        @connection.post(@path, options).on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end
      end
    end
  end
end

command :'distribute:api' do |c|
  c.syntax = "ipa distribute:api [options]"
  c.summary = "Distribute an .ipa file over custom API"
  c.description = ""

  c.example '', '$ ipa distribute:api --host http://api.someapp.com -f ./file.ipa -u username --path "/version.json" --data version=1.0&hello=world'
  
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-d', '--dsym FILE', "zipped .dsym package for the build"
  c.option '-h', '--host HOST', "API Host"
  c.option '-u', '--username USERNAME', "API username"
  c.option '-p', '--password PASSWORD', "API password"
  c.option '-P', '--path PATH', "API path"
  c.option '-D', '--data DATA', "Additional data to pass to the API"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_dsym! unless @dsym = options.dsym
    say_error "Specified dSYM.zip file doesn't exist" if @dsym and !File.exist?(@dsym)
    
    determine_api_host! unless @host = options.host
    say_error "Missing API host" and abort unless @host
        
    @username = options.username || ""
    @password = options.password || ""
    @path = options.path || ""
    
    parameters = {}
    parameters[:file] = @file
    parameters.merge!(data_hash_from_command_line(options.data))

    client = Shenzhen::Plugins::API::Client.new(@host, @username, @password, @path)
    response = client.upload_build(@file, parameters)
    case response.status
    when 200...300
      say_ok "Build successfully uploaded to API"
    else
      say_error "Error uploading to API: #{response.body}"
    end
  end

  private

  def determine_api_host!
    @host ||= ask "API host:"
  end
  
  def data_hash_from_command_line(data)
    Hash[data.split("&").map { |item| item.split("=") }]
  end
end
