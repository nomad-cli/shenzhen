module Shenzhen::Plugins
  module ITunesConnect
    ITUNES_CONNECT_SERVER = 'Xcode:itunesconnect.apple.com'

    class Client
      attr_reader :ipa, :sdk, :params

      def initialize(ipa, sdk, params = [])
        @ipa = ipa
        @sdk = sdk
        @params = params
      end

      def ensure_itunesconnect!
        case xcrun(:Validation, [:online])
        when /(error)|(fail)/i
          say_error "An error occurred checking the status of the app in iTunes Connect.\nRun with --verbose for more info." and abort
        when /validation was skipped/i
          say_error "Validation was skipped. Double check your credentials and ensure the app in the 'Waiting for Upload' state." and abort
        end
      end

      def upload_build!
        case xcrun(:Validation, [:online, :upload])
        when /(error)|(fail)/i
          say_error "An error occurred when trying to upload the build to iTunesConnect.\nRun with --verbose for more info." and abort
        end
      end

      private

      def xcrun(tool, options = [])
        args = ["xcrun", "-sdk #{sdk}", tool] + (options + @params).collect{|o| "-#{o}"} + [ipa, '2>&1']
        command = args.join(' ')

        say "#{command}" if verbose?

        output = `#{command}`
        say output.chomp if verbose?

        return output
      end

      def verbose?
        @params.collect(&:to_sym).include?(:verbose)
      end
    end
  end
end

command :'distribute:itunesconnect' do |c|
  c.syntax = "ipa distribute:itunesconnect [options]"
  c.summary = "Upload an .ipa file to iTunes Connect"
  c.description = "Upload an .ipa file directly to iTunes Connect for review. Requires that the app is in the 'Waiting for upload' state and the --upload flag to be set."
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-a', '--account ACCOUNT', "Apple ID used to log into https://itunesconnect.apple.com"
  c.option '-p', '--password PASSWORD', "Password for the account unless already stored in the keychain"
  c.option '-u', '--upload', "Actually attempt to upload the build to iTunes Connect"
  c.option '-w', '--warnings', "Check for warnings when validating the ipa"
  c.option '-e', '--errors', "Check for errors when validating the ipa"
  c.option '--verbose', "Run commands verbosely"
  c.option '--sdk SDK', "SDK to use when validating the ipa. Defaults to 'iphoneos'"
  c.option '--save-keychain', "Save the provided account in the keychain for future use"

  c.action do |args, options|
    options.default :upload => false, :sdk => 'iphoneos', :save_keychain => false

    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_itunes_connect_account! unless @account = options.account || ENV['ITUNES_CONNECT_ACCOUNT']
    say_error "Missing iTunes Connect account" and abort unless @account

    @password = options.password || ENV['ITUNES_CONNECT_PASSWORD']
    if @password ||= Security::GenericPassword.find(:s => ITUNES_CONNECT_SERVER, :a => @account)
      say_ok "Found password in keychain for account: #{@account}" if options.verbose
    else
      determine_itunes_connect_password! unless @password
      say_error "Missing iTunes Connect password" and abort unless @password

      Security::GenericPassword.add(ITUNES_CONNECT_SERVER, @account, @password, {:U => nil}) if options.save_keychain
    end

    parameters = []
    parameters << :verbose if options.verbose
    parameters << :warnings if options.warnings
    parameters << :errors if options.errors

    client = Shenzhen::Plugins::ITunesConnect::Client.new(@file, options.sdk, parameters)

    client.ensure_itunesconnect!
    say_warning "Upload not requested, skipping." and abort unless options.upload

    client.upload_build!
    say_ok "Upload complete. You may want to double check iTunes Connect to make sure it was received correctly."
  end

  private

  def determine_itunes_connect_account!
    @account ||= ask "iTunes Connect account:"
  end

  def determine_itunes_connect_password!
    @password ||= password "iTunes Connect password:"
  end
end
