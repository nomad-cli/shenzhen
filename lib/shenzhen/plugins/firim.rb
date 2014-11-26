require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module Firim
    class Client
      HOSTNAME = 'fir.im'
      VERSION = 'v2'

      def initialize(user_token)
        @user_token = user_token

        @connection = Faraday.new(:url => "http://#{HOSTNAME}") do |builder|
          builder.request :url_encoded
          builder.response :json
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def get_app_info(app_id)
        options = {
          :type => 'ios',
          :token => @user_token,
        }

        @connection.get("/api/#{VERSION}/app/info/#{app_id}", options) do |env|
          yield env[:status], env[:body] if block_given?
        end
      rescue Faraday::Error::TimeoutError
        say_error "Timed out while geting app info." and abort
      end

      def update_app_info(app_id, options)
        @connection.put("/api/#{VERSION}/app/#{app_id}?token=#{@user_token}", options) do |env|
          yield env[:status], env[:body] if block_given?
        end
      rescue Faraday::Error::TimeoutError
        say_error "Timed out while geting app info." and abort
      end

      def upload_build(ipa, options)
        connection = Faraday.new(:url => options['url'], :request => { :timeout => 360 }) do |builder|
          builder.request :multipart
          builder.response :json
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end

        options = {
          :key => options['type'],
          :token => options['token'],
          :file => Faraday::UploadIO.new(ipa, 'application/octet-stream')
        }

        connection.post('/', options).on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end
      rescue Errno::EPIPE
        say_error "Upload failed. Check internet connection is ok." and abort
      rescue Faraday::Error::TimeoutError
        say_error "Timed out while uploading build. Check https://fir.im// to see if the upload was completed." and abort
      end
    end
  end
end

command :'distribute:firim' do |c|
  c.syntax = "ipa distribute:firim [options]"
  c.summary = "Distribute an .ipa file over fir.im"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-u', '--user_token TOKEN', "User Token. Available at http://fir.im/user/info"
  c.option '-a', '--app_id APPID', "App Id (iOS Bundle identifier)"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_firim_user_token! unless @user_token = options.user_token || ENV['FIMIM_USER_TOKEN']
    say_error "Missing User Token" and abort unless @user_token

    determine_firim_app_id! unless @app_id = options.app_id || ENV['FIMIM_APP_ID']
    say_error "Missing App Id" and abort unless @app_id

    client = Shenzhen::Plugins::Firim::Client.new(@user_token)
    app_response = client.get_app_info(@app_id)
    if app_response.status == 200
      upload_response = client.upload_build(@file, app_response.body['bundle']['pkg'])

      if upload_response.status == 200
        oid = upload_response.body['appOid']
        today = Time.now.strftime('%Y-%m-%d %H:%M:%S')

        app_response = client.update_app_info(oid, {
          :changelog => "Upload on #{today}",
        })

        if app_response.status == 200
          say_ok "Build successfully uploaded to Firim"
        else
          say_error "Error uploading to Firim: #{response.body}" and abort
        end
      else
        say_error "Error uploading to Firim: #{response.body[:message]}" and abort
      end
    else
      say_error response.body
    end
  end

  private

  def determine_firim_user_token!
    @user_token ||= ask "User Token:"
  end

  def determine_firim_app_id!
    @app_id ||= ask "App Id:"
  end
end
