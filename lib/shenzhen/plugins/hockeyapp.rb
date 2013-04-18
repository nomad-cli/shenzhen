require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module HockeyApp
    class Client
      HOSTNAME = 'rink.hockeyapp.net'

      def initialize(api_token)
        @api_token = api_token
        @connection = Faraday.new(:url => "https://#{HOSTNAME}") do |builder|
          builder.request :multipart
          builder.request :url_encoded
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def upload_build(ipa, options)
        options[:ipa] = Faraday::UploadIO.new(ipa, 'application/octet-stream')

        if dsym_filename = options.delete(:dsym_filename)
          options[:dsym] = Faraday::UploadIO.new(dsym_filename, 'application/octet-stream')
        end

        @connection.post do |req|
          if options[:public_identifer].nil?
            req.url("/api/2/apps/upload")
          else
            req.url("/api/2/apps/#{options.delete(:public_identifer)}/app_versions")
          end
          req.headers['X-HockeyAppToken'] = @api_token
          req.body = options
        end.on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end
      end
    end
  end
end

command :'distribute:hockeyapp' do |c|
  c.syntax = "ipa distribute:hockeyapp [options]"
  c.summary = "Distribute an .ipa file over HockeyApp"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-d', '--dsym FILE', "zipped .dsym package for the build"
  c.option '-t', '--token TOKEN', "API Token. Available at https://rink.hockeyapp.net/manage/auth_tokens"
  c.option '-i', '--identifier PUBLIC_IDENTIFIER', "Public identifier of the app you are targeting, if not specified HockeyApp will use the bundle identifier to choose the right"
  c.option '-m', '--notes NOTES', "Release notes for the build (Default: Textile)"
  c.option '--markdown', 'Notes are written with Markdown'
  c.option '--tags TAGS', "Comma separated list of tags which will receive access to the build"
  c.option '--notify', "Notify permitted teammates to install the build"
  c.option '--downloadOff', "Upload but don't allow download of this version just yet"
  c.option '--mandatory', "Make this update mandatory"
  
  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_dsym! unless @dsym = options.dsym
    say_error "Specified dSYM.zip file doesn't exist" if @dsym and !File.exist?(@dsym)

    determine_hockeyapp_api_token! unless @api_token = options.token
    say_error "Missing API Token" and abort unless @api_token

    determine_notes! unless @notes = options.notes
    say_error "Missing release notes" and abort unless @notes

    parameters = {}
    parameters[:public_identifer] = options.identifier if options.identifier
    parameters[:notes] = @notes
    parameters[:notes_type] = options.markdown ? "1" : "0"
    parameters[:notify] = "1" if options.notify && !options.downloadOff
    parameters[:status] = options.downloadOff ? "1" : "2"
    parameters[:tags] = options.tags if options.tags
    parameters[:dsym_filename] = @dsym if @dsym
    parameters[:mandatory] = "1" if options.mandatory

    client = Shenzhen::Plugins::HockeyApp::Client.new(@api_token)
    response = client.upload_build(@file, parameters)
    case response.status
    when 200...300
      say_ok "Build successfully uploaded to HockeyApp"
    else
      say_error "Error uploading to HockeyApp: #{response.body}"
    end
  end

  private

  def determine_hockeyapp_api_token!
    @api_token ||= ask "API Token:"
  end
end
