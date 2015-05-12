require 'json'
require 'openssl'
require 'faraday'
require 'faraday_middleware'

module Shenzhen::Plugins
  module HockeyApp
    class Client
      UPLOAD_HOSTNAME = 'upload.hockeyapp.net'
      UPDATE_HOSTNAME = 'rink.hockeyapp.net'

      attr_reader :response

      def initialize(api_token)
        @api_token = api_token
      end

      def upload_build(ipa_file, dsym_files, options)
        upload_ipa(ipa_file, options) if ipa_file
        upload_dsyms(dsym_files, options) if dsym_files and should_continue?(@response)
      end

      private

      def upload_ipa(ipa, options)
        options[:ipa] = Faraday::UploadIO.new(ipa, 'application/octet-stream') if ipa and File.exist?(ipa)

        run_request_for_options(options)

        options.delete(:ipa)
      end

      def upload_dsyms(dsym_filenames, options)
        dsym_filenames.each { |dsym_filename| upload_dsym(dsym_filename, options) if should_continue?(@response) }
      end

      def upload_dsym(dsym_filename, options)
        options[:dsym] = Faraday::UploadIO.new(dsym_filename, 'application/octet-stream')

        run_request_for_options(options)

        options.delete(:dsym)
      end

      def process_post_response(response, options)
        options[:public_identifier] ||= response.body['public_identifier']
        @version_number = response.body['id']
      end

      def connection(hostname)
        Faraday.new(:url => "https://#{hostname}") do |builder|
          builder.request :multipart
          builder.request :url_encoded
          builder.response :json, :content_type => /\bjson$/
          builder.use FaradayMiddleware::FollowRedirects
          builder.adapter :net_http
        end
      end

      def run_request_for_options(options)
        if options[:public_identifier] and @version_number
          @response = connection(UPDATE_HOSTNAME).put do |req|
            req.url("api/2/apps/#{options[:public_identifier]}/app_versions/#{@version_number}")
            configure_request(req, options)
          end.on_complete do |env|
            yield env[:status], env[:body] if block_given?
          end
        else
          @response = connection(UPLOAD_HOSTNAME).post do |req|
            req.url(options[:public_identifier] ? "api/2/apps/#{options[:public_identifier]}/app_versions/upload" : 'api/2/apps/upload')
            configure_request(req, options)
          end.on_complete do |env|
            yield env[:status], env[:body] if block_given?
          end

          process_post_response(@response, options)
        end
      end

      def configure_request(request, options)
        request.headers['X-HockeyAppToken'] = @api_token
        request.body = options
      end

    end
  end
end

command :'distribute:hockeyapp' do |c|
  c.syntax = "ipa distribute:hockeyapp [options]"
  c.summary = "Distribute an .ipa file over HockeyApp"
  c.description = ""
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-d', '--dsym FILES', Array, "Comma separated list of .dSYM.zip packages for the build"
  c.option '-a', '--token TOKEN', "API Token. Available at https://rink.hockeyapp.net/manage/auth_tokens"
  c.option '-i', '--identifier PUBLIC_IDENTIFIER', "Public identifier of the app you are targeting, if not specified HockeyApp will use the bundle identifier to choose the right"
  c.option '-m', '--notes NOTES', "Release notes for the build (Default: Textile)"
  c.option '-r', '--release RELEASE', [:beta, :store, :alpha, :enterprise], "Release type: 0 - Beta, 1 - Store, 2 - Alpha , 3 - Enterprise"
  c.option '--markdown', 'Notes are written with Markdown'
  c.option '--tags TAGS', "Comma separated list of tags which will receive access to the build"
  c.option '--notify', "Notify permitted teammates to install the build"
  c.option '--downloadOff', "Upload but don't allow download of this version just yet"
  c.option '--mandatory', "Make this update mandatory"
  c.option '--commit-sha SHA', "The Git commit SHA for this build"
  c.option '--build-server-url URL', "The URL of the build job on your build server"
  c.option '--repository-url URL', "The URL of your source repository"
  c.option '--noIpa', "Do not upload an .ipa file with this build"

  c.action do |args, options|
    unless options.noIpa
      determine_file! unless @file = options.file
      say_warning "Missing or unspecified .ipa file" unless @file and File.exist?(@file)
    end

    determine_dsyms! unless @dsyms = options.dsym
    say_warning "Specified dSYM.zip files don't exist" if @dsyms and @dsyms.any? { |dsym_file| !File.exist?(dsym_file) }

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
    client.upload_build(@file, @dsyms, parameters)
    if response_ok?(client.response)
      say_ok "Version files successfully uploaded to HockeyApp: #{@file} #{@dsyms}"
    else
      say_error "Error uploading to HockeyApp: #{client.response.body}"
    end
  end

  private

  def determine_hockeyapp_api_token!
    @api_token ||= ask "API Token:"
  end
end

def should_continue?(response)
  !response or response_ok?(response)
end

def response_ok?(response)
  (200...300).include?(response.status)
end

