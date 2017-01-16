require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module Fir
    class Client
      HOSTNAME = 'api.fir.im'
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

      
      #
      #get upload ticket
      #
      def get_upload_ticket bundle_id
        options = {
          :type => 'ios',
          :bundle_id => bundle_id,
          :api_token => @user_token
        }

        response = @connection.post('/apps', options) do |env|
          yield env[:status], env[:body] if block_given?
        end

      rescue Faraday::Error::TimeoutError
        say_error "Timed out while geting upload ticket." and abort 
      end

      #
      #upload file
      #
      def upload_file_and_update_app_info ipa, options
        connection = Faraday.new(:url => options['upload_url'], :request => { :timeout => 360 }) do |builder|
          builder.request :multipart
          builder.response :json
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end

        form_options = {
          :key => options['key'],
          :token => options['token'],
          :file => Faraday::UploadIO.new(ipa, 'application/octet-stream'),
          "x:name" => options[:name],
          "x:version" => options[:version],
          "x:build" => options[:build],
          "x:release_type" => options[:release_type],
          "x:changelog" => options[:changelog]
        }
        p "=================uploading====================="
        connection.post('/', form_options).on_complete do |env|
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

command :'distribute:fir' do |c|
  c.syntax = "ipa distribute:fir [options]"
  c.summary = "请使用新版api_token => http://fir.im/user/info 获取 \n Distribute an .ipa file over fir.im"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-u', '--user_token TOKEN', "User Token. Available at http://fir.im/user/info"
  c.option '-a', '--app_id APPID', "App Id (iOS Bundle identifier)"
  c.option '-n', '--notes NOTES', "Release notes for the build"
  c.option '-N', '--app_name APP_NAME', "the name for app"
  c.option '-R', '--release_type RELEASE_TYPE', "release_type for app default adhoc"
  c.option '-V', '--app_version VERSION', "App Version"
  c.option '-S', '--short_version SHORT', "App Short Version"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_fir_user_token! unless @user_token = options.user_token || ENV['FIR_USER_TOKEN']
    say_error "Missing User Token" and abort unless @user_token
    determine_fir_app_id! unless @app_id = options.app_id || ENV['FIR_APP_ID']
    say_error "Missing App Id" and abort unless @app_id

    determine_notes! unless @notes = options.notes
    say_error "Missing release notes" and abort unless @notes

    determine_app_version! unless @app_version = options.app_version

    determine_short_version! unless @short_version = options.short_version

    client = Shenzhen::Plugins::Fir::Client.new(@user_token)
    #get upload ticket
    app_response = client.get_upload_ticket(@app_id)
    if app_response.status == 201

      upload_app_options = app_response.body['cert']['binary']
      app_short_uri = app_response.body['short']
      if options.app_name || ENV['APP_NAME']
        upload_app_options[:name] = options.app_name || ENV['APP_NAME']
      end
      upload_app_options[:release_type] = options.release_type || "adhoc"
      upload_app_options[:version] = options.short_version
      upload_app_options[:build] = options.app_version
      upload_app_options[:changelog] = options.notes

      #upload file
      upload_response = client.upload_file_and_update_app_info(@file, upload_app_options)

      if upload_response.status == 200
        say_ok "Build successfully uploaded to Fir, visit url: http://fir.im/#{app_short_uri}"
      else
        say_error "Error uploading to Fir: #{upload_response.body[:error]}" and abort
      end
    else
      say_error "Error getting app information: #{app_response.body[:error]}"
    end
  end

  private

  def determine_fir_user_token!
    @user_token ||= ask "User Token:"
  end

  def determine_fir_app_id!
    @app_id ||= ask "App Id:"
  end

  def determine_app_version!
    @app_version ||= ask "App Version:"
  end

  def determine_short_version!
    @short_version ||= ask "Short Version:"
  end
end