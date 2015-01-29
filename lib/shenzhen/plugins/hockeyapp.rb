require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module HockeyApp
    class Client
      HOSTNAME = 'upload.hockeyapp.net'

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
        options[:ipa] = Faraday::UploadIO.new(ipa, 'application/octet-stream') if ipa and File.exist?(ipa)

        if dsym_filename = options.delete(:dsym_filename)
          options[:dsym] = Faraday::UploadIO.new(dsym_filename, 'application/octet-stream')
        end

        @connection.post do |req|
          if options[:public_identifier].nil?
            req.url("/api/2/apps/upload")
          else
            req.url("/api/2/apps/#{options.delete(:public_identifier)}/app_versions/upload")
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
  c.option '-a', '--token TOKEN', "API Token. Available at https://rink.hockeyapp.net/manage/auth_tokens"
  c.option '-i', '--identifier PUBLIC_IDENTIFIER', "Public identifier of the app you are targeting, if not specified HockeyApp will use the bundle identifier to choose the right"
  c.option '-m', '--notes NOTES', "Release notes for the build (Default: Textile)"
  c.option '-r', '--release RELEASE', [:beta, :store, :alpha, :enterprise], "Release type: 0 - Beta, 1 - Store, 2 - Alpha , 3 - Enterprise"
  c.option '--markdown', 'Notes are written with Markdown'
  c.option '--tags TAGS', "Comma separated list of tags which will receive access to the build"
  c.option '--teams TEAMS', "Comma separated list of team ID numbers to which this build will be restricted"
  c.option '--users USERS', "Comma separated list of user ID numbers to which this build will be restricted"
  c.option '--notify', "Notify permitted teammates to install the build"
  c.option '--downloadOff', "Upload but don't allow download of this version just yet"
  c.option '--mandatory', "Make this update mandatory"
  c.option '--commit-sha SHA', "The Git commit SHA for this build"
  c.option '--build-server-url URL', "The URL of the build job on your build server"
  c.option '--repository-url URL', "The URL of your source repository"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_warning "Missing or unspecified .ipa file" unless @file and File.exist?(@file)

    determine_dsym! unless @dsym = options.dsym
    say_warning "Specified dSYM.zip file doesn't exist" if @dsym and !File.exist?(@dsym)

    determine_hockeyapp_api_token! unless @api_token = options.token || ENV['HOCKEYAPP_API_TOKEN']
    say_error "Missing API Token" and abort unless @api_token

    determine_notes! unless @notes = options.notes
    say_error "Missing release notes" and abort unless @notes

    parameters = {}
    parameters[:public_identifier] = options.identifier if options.identifier
    parameters[:notes] = @notes
    parameters[:notes_type] = options.markdown ? "1" : "0"
    parameters[:notify] = "1" if options.notify && !options.downloadOff
    parameters[:status] = options.downloadOff ? "1" : "2"
    parameters[:tags] = options.tags if options.tags
    parameters[:teams] = options.teams if options.teams
    parameters[:users] = options.users if options.users
    parameters[:dsym_filename] = @dsym if @dsym
    parameters[:mandatory] = "1" if options.mandatory
    parameters[:release_type] = case options.release
                                when :beta
                                  "0"
                                when :store
                                  "1"
                                when :alpha 
                                  "2"
                                when :enterprise
                                  "3"
                                end
    parameters[:commit_sha] = options.commit_sha if options.commit_sha
    parameters[:build_server_url] = options.build_server_url if options.build_server_url
    parameters[:repository_url] = options.repository_url if options.repository_url

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
