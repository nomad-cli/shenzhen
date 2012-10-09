require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module TestFlight
    class Client
      HOSTNAME = 'testflightapp.com'

      def initialize(api_token, team_token)
        @api_token, @team_token = api_token, team_token
        @connection = Faraday.new(:url => "http://#{HOSTNAME}") do |builder|
          builder.request :multipart
          builder.request :json
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def upload_build(ipa, options)
        options.update({
          :api_token => @api_token,
          :team_token => @team_token,
          :file => Faraday::UploadIO.new(ipa, 'application/octet-stream')
        })

        if dsym_filename = options.delete(:dsym_filename)
          options[:dsym] = Faraday::UploadIO.new(dsym_filename, 'application/octet-stream')
        end

        @connection.post("/api/builds.json", options).on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end
      end
    end
  end
end

command :'distribute:testflight' do |c|
  c.syntax = "ipa distribute:testflight [options]"
  c.summary = "Distribute an .ipa file over testflight"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-d', '--dsym FILE', "zipped .dsym package for the build"
  c.option '-a', '--api_token TOKEN', "API Token. Available at https://testflightapp.com/account/#api-token"
  c.option '-T', '--team_token TOKEN', "Team Token. Available at https://testflightapp.com/dashboard/team/edit/"
  c.option '-m', '--notes NOTES', "Release notes for the build"
  c.option '-l', '--lists LISTS', "Comma separated distribution list names which will receive access to the build"
  c.option '--notify', "Notify permitted teammates to install the build"
  c.option '--replace', "Replace binary for an existing build if one is found with the same name/bundle version"
  c.option '-q', '--quiet', "Silence warning and success messages"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_dsym! unless @dsym = options.dsym
    say_error "Specified dSYM.zip file doesn't exist" if @dsym and !File.exist?(@dsym)

    determine_api_token! unless @api_token = options.api_token
    say_error "Missing API Token" and abort unless @api_token

    determine_team_token! unless @team_token = options.team_token
    
    determine_notes! unless @notes = options.notes
    say_error "Missing release notes" and abort unless @notes

    parameters = {}
    parameters[:file] = @file
    parameters[:notes] = @notes
    parameters[:dsym_filename] = @dsym if @dsym
    parameters[:notify] = "true" if options.notify
    parameters[:replace] = "true" if options.replace
    parameters[:distribution_lists] = options.lists if options.lists

    client = Shenzhen::Plugins::TestFlight::Client.new(@api_token, @team_token)
    response = client.upload_build(@file, parameters)
    case response.status
    when 200...300
      say_ok "Build successfully uploaded to TestFlight"
    else
      say_error "Error uploading to TestFlight: #{response.body}"
    end
  end

  private

  def determine_api_token!
    @api_token ||= ask "API Token:"
  end

  def determine_team_token!
    @team_token ||= ask "Team Token:"
  end

  def determine_file!
    files = Dir['*.ipa']
    @file ||= case files.length
              when 0 then nil
              when 1 then files.first
              else
                @file = choose "Select an .ipa File:", *files
              end
  end

  def determine_dsym!
    dsym_files = Dir['*.dSYM.zip']
    @dsym ||= case dsym_files.length
              when 0 then nil
              when 1 then dsym_files.first
              else
                @dsym = choose "Select a .dSYM.zip file:", *dsym_files
              end
  end

  def determine_notes!
    placeholder = %{What's new in this release: }
    
    @notes = ask_editor placeholder
    @notes = nil if @notes == placeholder
  end
end
