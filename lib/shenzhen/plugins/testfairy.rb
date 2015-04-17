require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module TestFairy
    class Client
      HOSTNAME = 'app.testfairy.com'

      def initialize(api_key)
        @api_key = api_key
        @connection = Faraday.new(:url => "https://#{HOSTNAME}") do |builder|
          builder.request :multipart
          builder.request :url_encoded
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def upload_build(ipa, options)
        options[:file] = Faraday::UploadIO.new(ipa, 'application/octet-stream') if ipa and File.exist?(ipa)

        if symbols_file = options.delete(:symbols_file)
          options[:symbols_file] = Faraday::UploadIO.new(symbols_file, 'application/octet-stream')
        end

        @connection.post do |req|
          req.url("/api/upload/")
          req.body = options
        end.on_complete do |env|
          yield env[:status], env[:body] if block_given?
        end
      end
    end
  end
end

command :'distribute:testfairy' do |c|
  c.syntax = "ipa distribute:testfairy [options]"
  c.summary = "Distribute an .ipa file over TestFairy"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-d', '--dsym FILE', "zipped .dsym package for the build"
  c.option '-a', '--key KEY', "API Key. Available at https://app.testfairy.com/settings for details."
  c.option '-c', '--comment COMMENT', "Comment for the build"
  c.option '--tester-groups GROUPS', 'Comma-separated list of tester groups to be notified on the new build. Or "all" to notify all testers.'
  c.option '--metrics METRICS', "Comma-separated list of metrics to record"
  c.option '--max-duration DURATION', 'Maximum session recording length, eg 20m or 1h. Default is "10m". Maximum 24h.'
  c.option '--video ACTIVE', 'Video recording settings "on", "off" or "wifi" for recording video only when wifi is available. Default is "on".'
  c.option '--video-quality QUALITY', 'Video quality settings, "high", "medium" or "low". Default is "high".'
  c.option '--video-rate RATE', 'Video rate recording in frames per second, default is "1.0".'
  c.option '--icon-watermark ADD', 'Add a small watermark to app icon. Default is "off".'

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_warning "Missing or unspecified .ipa file" unless @file and File.exist?(@file)

    determine_dsym! unless @dsym = options.dsym
    say_warning "Specified dSYM.zip file doesn't exist" if @dsym and !File.exist?(@dsym)

    determine_testfairy_api_key! unless @api_key = options.key || ENV['TESTFAIRY_API_KEY']
    say_error "Missing API Key" and abort unless @api_key

    determine_notes! unless @comment = options.comment
    say_error "Missing release comment" and abort unless @comment

    parameters = {}
    # Required
    parameters[:api_key] = @api_key
    # Optional
    parameters[:comment] = @comment
    parameters[:symbols_file] = @dsym if @dsym
    parameters[:testers_groups] = options.testers_groups if options.testers_groups
    parameters[:'max-duration'] = options.max_duration if options.max_duration
    parameters[:video] = options.video if options.video
    parameters[:'video-quality'] = options.video_quality if options.video_quality
    parameters[:'video-rate'] = options.video_rate if options.video_rate
    parameters[:'icon-watermark'] = options.icon_watermark if options.icon_watermark
    parameters[:metrics] = options.metrics if options.metrics


    client = Shenzhen::Plugins::TestFairy::Client.new(@api_key)
    response = client.upload_build(@file, parameters)
    case response.status
    when 200...300
      say_ok "Build successfully uploaded to TestFairy"
    else
      say_error "Error uploading to TestFairy: #{response.body}"
    end
  end

  private

  def determine_testfairy_api_key!
    @api_key ||= ask "API Key:"
  end
end
