require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module DeployGate
    class Client
      HOSTNAME = 'deploygate.com'

      def initialize(api_token, user_name)
        @api_token, @user_name = api_token, user_name
        @connection = Faraday.new(:url => "https://#{HOSTNAME}", :request => { :timeout => 120 }) do |builder|
          builder.request :multipart
          builder.request :json
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def upload_build(ipa, options)
        options.update({
          :token => @api_token,
          :file => Faraday::UploadIO.new(ipa, 'application/octet-stream'),
          :message => options[:message] || ''
        })

        @connection.post("/api/users/#{@user_name}/apps", options).on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end

      rescue Faraday::Error::TimeoutError
        say_error "Timed out while uploading build. Check https://deploygate.com/ to see if the upload was completed." and abort
      end
    end
  end
end

command :'distribute:deploygate' do |c|
  c.syntax = "ipa distribute:deploygate [options]"
  c.summary = "Distribute an .ipa file over deploygate"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-a', '--api_token TOKEN', "API Token. Available at https://deploygate.com/settings"
  c.option '-u', '--user_name USER_NAME', "User Name. Available at https://deploygate.com/settings"
  c.option '-m', '--message MESSAGE', "Release message for the build"
  c.option '-d', '--distribution_key DESTRIBUTION_KEY', "distribution key for distribution page"
  c.option '-n', '--disable_notify', "disable notification"
  c.option '-r', '--release_note RELEASE_NOTE', "release note for distribution page"
  c.option '-v', '--visibility (private|public)', "privacy setting ( require public for personal free account)"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_deploygate_api_token! unless @api_token = options.api_token || ENV['DEPLOYGATE_API_TOKEN']
    say_error "Missing API Token" and abort unless @api_token

    determine_deploygate_user_name! unless @user_name = options.user_name || ENV['DEPLOYGATE_USER_NAME']
    say_error "Missing User Name" and abort unless @api_token

    @message = options.message
    @distribution_key = options.distribution_key || ENV['DEPLOYGATE_DESTRIBUTION_KEY']
    @release_note = options.release_note
    @disable_notify = ! options.disable_notify.nil? ? "yes" : nil
    @visibility = options.visibility
    @message = options.message

    parameters = {}
    parameters[:file] = @file
    parameters[:message] = @message
    parameters[:distribution_key] = @distribution_key if @distribution_key
    parameters[:release_note] = @release_note if  @release_note
    parameters[:disable_notify] = @disable_notify if @disable_notify
    parameters[:visibility] = @visibility if @visibility
    parameters[:replace] = "true" if options.replace

    client = Shenzhen::Plugins::DeployGate::Client.new(@api_token, @user_name)
    response = client.upload_build(@file, parameters)
    if (200...300) === response.status and not response.body["error"]
      say_ok "Build successfully uploaded to DeployGate"
    else
      say_error "Error uploading to DeployGate: #{response.body["error"] || "(Unknown Error)"}" and abort
    end
  end

  private

  def determine_deploygate_api_token!
    @api_token ||= ask "API Token:"
  end

  def determine_deploygate_user_name!
    @user_name ||= ask "User Name:"
  end
end
