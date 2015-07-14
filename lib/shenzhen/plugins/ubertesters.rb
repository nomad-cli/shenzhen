require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module Ubertesters
    class Client
      HOSTNAME = 'beta.ubertesters.com/api/client/upload_build.json'
      def initialize(api_key)
        @api_key = api_key
        @connection = Faraday.new(:url => "http://#{HOSTNAME}", :request => { :timeout => 1800 }) do |builder|
          builder.request :multipart
          builder.request :json
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def upload_build(ipa, options)
        options[:file] = Faraday::UploadIO.new(ipa, 'application/octet-stream') if ipa and File.exist?(ipa)

        @connection.post do |req|
          req.headers['X-UbertestersApiKey'] = @api_key
          req.body = options
        end.on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end
      end
    end
  end
end

command :'distribute:ubertesters' do |c|
  c.syntax = "ipa distribute:ubertesters [options]"
  c.summary = "Distribute an .ipa file over Ubertesters"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-a', '--api_key TOKEN', "API key. Available at https://http://beta.ubertesters.com/profile/api_access"
  c.option '-t', '--title TITLE', "Build title"
  c.option '-m', '--notes NOTES', "Build notes"
  c.option '-s', '--status STATUS', "pending - default, create a new revision only - in_progress - create and start revision"
  c.option '-k', '--stop_previous STOP_PREVIOUS [true | false]', "Stop all previous revisions?"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_ubertesters_api_key! unless @api_key = options.api_key || ENV['UBERTESTERS_API_KEY']
    say_error "Missing API Key" and abort unless @api_key


    parameters = {}
    parameters[:file] = @file
    parameters[:title] = options.title if options.title
    parameters[:notes] = options.notes if options.notes
    parameters[:status] = options.status if options.status
    parameters[:stop_previous] = options.stop_previous if options.stop_previous
    
    client = Shenzhen::Plugins::Ubertesters::Client.new(@api_key)
    response = client.upload_build(@file, parameters)
    if (200...300) === response.status and response.body["success"]
        say_ok "Build successfully uploaded to Ubertesters"
    else
        say_error "Error uploading to Ubertesters: #{response.body["errors"] || "(Unknown Error)"}" and abort
    end
  end

  private


  def determine_ubertesters_api_key!
    @api_key ||= ask "API Key:"
  end

end
