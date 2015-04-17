require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module RivieraBuild
    class Client
      HOSTNAME = 'apps.rivierabuild.com'

      def initialize(api_token)
        @api_token = api_token
        @connection = Faraday.new(:url => "https://#{HOSTNAME}", :request => { :timeout => 120 }) do |builder|
          builder.request :multipart
          builder.request :url_encoded
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def upload_build(ipa, options)
        options[:file] = Faraday::UploadIO.new(ipa, 'application/octet-stream') if ipa and File.exist?(ipa)

        @connection.post do |req|
          req.url("/api/upload")
          req.body = options
        end.on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end
      end
    end
  end
end

command :'distribute:rivierabuild' do |c|
  c.syntax = "ipa distribute:rivierabuild [options]"
  c.summary = "Distribute an .ipa file over RivieraBuild"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-k', '--key KEY', "API KEY. Available at https://apps.rivierabuild.com/settings"
  c.option '-a', '--availability AVAILABILITY', "For how long the build will be available? More info: http://api.rivierabuild.com"
  c.option '-p', '--passcode PASSCODE', "Optional passcode required to install the build on a device"
  c.option '-n', '--note NOTE', "Release notes for the build, Markdown"
  c.option '--commit-sha SHA', "The Git commit SHA for this build"
  c.option '--app-id', "Riviera Build Application ID"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_warning "Missing or unspecified .ipa file" unless @file and File.exist?(@file)

    determine_rivierabuild_api_token! unless @api_token = options.key || ENV['RIVIERA_API_KEY']
    say_error "Missing API Token" and abort unless @api_token

    determine_availability! unless @availability = options.availability
    say_error "Missing availability" and abort unless @availability

    parameters = {}
    parameters[:api_key] = @api_token
    parameters[:availability] = @availability
    parameters[:passcode] = options.passcode if options.passcode
    parameters[:app_id] = options.app_id if options.app_id
    parameters[:note] = options.note if options.note
    parameters[:commit_sha] = options.commit_sha if options.commit_sha

    client = Shenzhen::Plugins::RivieraBuild::Client.new(@api_token)
    response = client.upload_build(@file, parameters)
    case response.status
    when 200...300
      say_ok "Build successfully uploaded to RivieraBuild: #{response.body['file_url']}"
    else
      say_error "Error uploading to RivieraBuild: #{response.body}"
    end
  end

  private

  def determine_rivierabuild_api_token!
    @api_token ||= ask "API Key:"
  end
end
