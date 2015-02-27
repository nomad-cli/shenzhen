require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module Pgyer
    class Client
      HOSTNAME = 'www.pgyer.com'

      def initialize(user_key, api_key)
        @user_key, @api_key = user_key, api_key
        @connection = Faraday.new(:url => "http://#{HOSTNAME}", :request => { :timeout => 120 }) do |builder|
          builder.request :multipart
          builder.request :json
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def upload_build(ipa, options)
        options.update({
          :uKey => @user_key,
          :_api_key => @api_key,
          :file => Faraday::UploadIO.new(ipa, 'application/octet-stream')
        })

        @connection.post("/apiv1/app/upload", options).on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end

      rescue Faraday::Error::TimeoutError
        say_error "Timed out while uploading build. Check http://www.pgyer.com/my to see if the upload was completed." and abort
      end

      def update_app_info(options)
        connection = Faraday.new(:url => "http://#{HOSTNAME}", :request => { :timeout => 120 }) do |builder|
          builder.request :url_encoded
          builder.request :json
          builder.response :logger
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end

        options.update({
          :uKey => @user_key,
          :_api_key => @api_key,
        })

        connection.post("/apiv1/app/update", options) do |env|
          yield env[:status], env[:body] if block_given?
        end

      rescue Faraday::Error::TimeoutError
        say_error "Timed out while uploading build. Check http://www.pgyer.com/my to see if the upload was completed." and abort
      end
    end
  end
end

command :'distribute:pgyer' do |c|
  c.syntax = "ipa distribute:pgyer [options]"
  c.summary = "Distribute an .ipa file over Pgyer"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-a', '--api_key KEY', "API KEY. Available at http://www.pgyer.com/doc/api#uploadApp"
  c.option '-u', '--user_key KEY', "USER KEY. Available at http://www.pgyer.com/doc/api#uploadApp/"
  c.option '--range RANGE', "Publish range. e.g. 1 (default), 2, 3"
  c.option '--[no-]public', "Allow build app on public to download. it is not public default."
  c.option '--password PASSWORD', "Set password to allow visit app web page."

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_pgyer_user_key! unless @user_key = options.user_key || ENV['PGYER_USER_KEY']
    say_error "Missing User Key" and abort unless @user_key

    determine_pgyer_api_key! unless @api_key = options.api_key || ENV['PGYER_API_KEY']
    say_error "Missing API Key" and abort unless @api_key

    determine_publish_range! unless @publish_range = options.range
    say_error "Missing Publish Range" and abort unless @publish_range

    determine_is_public! unless @is_public = !!options.public
    @is_public = @is_public ? 1 : 2

    parameters = {}
    parameters[:publishRange] = @publish_range
    parameters[:isPublishToPublic] = @is_public
    parameters[:password] = options.password.chomp if options.password

    client = Shenzhen::Plugins::Pgyer::Client.new(@user_key, @api_key)
    response = client.upload_build(@file, parameters)
    case response.status
    when 200...300
      app_id = response.body['appKey']
      app_short_uri = response.body['appShortcutUrl']

      app_response = client.update_app_info({
        :aKey => app_id,
        :appUpdateDescription => @notes
      })

      if app_response.status == 200
        say_ok "Build successfully uploaded to Pgyer, visit url: http://www.pgyer.com/#{app_short_uri}"
      else
        say_error "Error update build information: #{response.body}" and abort
      end
    else
      say_error "Error uploading to Pgyer: #{response.body}" and abort
    end
  end

  private

  def determine_pgyer_api_key!
    @api_key ||= ask "API Key:"
  end

  def determine_pgyer_user_key!
    @user_key ||= ask "User Key:"
  end

  def determine_publish_range!
    @publish_range ||= "1"
  end

  def determine_is_public!
    @is_public ||= false
  end

end
