module Shenzhen::Plugins
  module ITunesConnect

    class KeychainHelper

      class << self

        def keychain_password_exists?(account)
          options = {:a => account}
          run_keychain_command(:find, options)
          $?.success?
        end

        def create_keychain_password(account, password)
          options = {:a => account, :w => password, :U => nil}
          run_keychain_command(:add, options)
        end

        def delete_keychain_password(account)
          options = {:a => account}
          run_keychain_command(:delete, options)
        end

        def run_keychain_command(cmd, options={})
          options.merge!({:s => 'Xcode:itunesconnect.apple.com'})
          args = ["security #{cmd}-generic-password"] + options.map {|k,v| "-#{k} #{v}".strip} << "2>&1"
          command = args.join(' ')
          `#{command}`
        end

      end

    end

    class Client

      attr_reader :ipa, :sdk, :params, :verbose

      def initialize(ipa, sdk, params=[])
        @ipa = ipa
        @sdk = sdk
        @params = params
        @verbose = true if @params.include? :verbose
      end

      def ensure_itunesconnect!
        output = xcrun(:Validation, [:online])
        say output.chomp if verbose
        # xcrun exits 0 even if there was an error
        if !$?.success? || /(error)|(fail)/i.match(output)
          say_error "An error occurred checking the status of the app in iTunes Connect.\nRun with --verbose for more info." and abort
        elsif /validation was skipped/i.match(output)
          say_error "Validation was skipped. Double check your credentials and ensure the app in the 'Waiting for Upload' state." and abort
        end
      end

      def upload_build!
        output = xcrun(:Validation, [:online, :upload])
        say output.chomp if verbose
        if !$?.success? || /(error)|(fail)/i.match(output)
          say_error "An error occurred when trying to upload the build to iTunesConnect.\nRun with --verbose for more info." and abort
        end
      end

      private
        def xcrun(tool, options=[])
          options.concat(params)
          args = ["xcrun", "-sdk #{sdk}", tool] + options.map {|o| "-#{o}"} + [ipa, '2>&1']
          command = args.join(' ')
          say "#{command}" if verbose
          `#{command}`
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

    determine_itunesconnect_account! unless @account = options.account || ENV['ITUNESCONNECT_ACCOUNT']
    say_error "Missing iTunes Connect account" and abort unless @account

    determine_itunesconnect_password! unless @password = options.password || ENV['ITUNESCONNECT_PASSWORD']
    say_error "Missing iTunes Connect password" and abort unless @password || @keychain_password

    if @keychain_password
      say_ok "Found password in keychain for account: #{@account}" if options.verbose
    else
      Shenzhen::Plugins::ITunesConnect::KeychainHelper.create_keychain_password(@account, @password)
    end

    parameters = []
    parameters << :verbose if options.verbose
    parameters << :warnings if options.warnings
    parameters << :errors if options.errors

    client = Shenzhen::Plugins::ITunesConnect::Client.new(@file, options.sdk, parameters)

    # we want to make sure we clean up the keychain even if the commands fail
    begin
      client.ensure_itunesconnect!
      say_warning "Upload not requested, skipping." and abort unless options.upload
      client.upload_build!
      say_ok "Upload complete. You may want to double check iTunes Connect to make sure it was received correctly."
    ensure
      Shenzhen::Plugins::ITunesConnect::KeychainHelper.delete_keychain_password(@account) unless @keychain_password || options.save_keychain
    end

  end

  private

  def determine_itunesconnect_account!
    @account ||= ask "iTunes Connect account:"
  end

  def determine_itunesconnect_password!
    @password ||= begin
      if @keychain_password = Shenzhen::Plugins::ITunesConnect::KeychainHelper.keychain_password_exists?(@account)
        p = false
      else
        p = password "iTunes Connect password:"
      end
      p
    end
  end

end
