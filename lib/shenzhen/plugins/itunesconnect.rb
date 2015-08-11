require 'security'
require 'fileutils'
require 'digest/md5'
require 'shellwords'

module Shenzhen::Plugins
  module ITunesConnect
    ITUNES_CONNECT_SERVER = 'Xcode:itunesconnect.apple.com'

    class Client
      attr_reader :ipa, :sdk, :params

      def initialize(ipa, apple_id, sdk, account, password, params = [])
        @ipa = ipa
        @apple_id = apple_id
        @sdk = sdk
        @account = account
        @password = password
        @params = params
        @filename = File.basename(@ipa).tr(" ", "_")
      end

      def upload_build!
        size = File.size(@ipa)
        checksum = Digest::MD5.file(@ipa)

        begin
          FileUtils.mkdir_p("Package.itmsp")
          FileUtils.copy_entry(@ipa, "Package.itmsp/#{@filename}")

          File.write("Package.itmsp/metadata.xml", metadata(@apple_id, checksum, size))

          raise if /(error)|(fail)/i === transport
        rescue
          say_error "An error occurred when trying to upload the build to iTunesConnect.\nRun with --verbose for more info." and abort
        ensure
          FileUtils.rm_rf("Package.itmsp", :secure => true)
        end
      end

      private

      def transport
        xcode = `xcode-select --print-path`.strip
        tool = File.join(File.dirname(xcode), "Applications/Application Loader.app/Contents/MacOS/itms/bin/iTMSTransporter").gsub(/\s/, '\ ')
        tool = File.join(File.dirname(xcode), "Applications/Application Loader.app/Contents/itms/bin/iTMSTransporter").gsub(/\s/, '\ ') if !File.exist?(tool)

        escaped_password = Shellwords.escape(@password)
        args = [tool, "-m upload", "-f Package.itmsp", "-u #{Shellwords.escape(@account)}", "-p #{escaped_password}"]
        command = args.join(' ')

        puts command.sub("-p #{escaped_password}", "-p ******") if $verbose

        output = `#{command} 2> /dev/null`
        puts output.chomp if $verbose

        raise "Failed to upload package to iTunes Connect" unless $?.exitstatus == 0

        output
      end

      def metadata(apple_id, checksum, size)
        %{<?xml version="1.0" encoding="UTF-8"?>
          <package version="software4.7" xmlns="http://apple.com/itunes/importer">
            <software_assets apple_id="#{apple_id}">
              <asset type="bundle">
                <data_file>
                  <file_name>#{@filename}</file_name>
                  <checksum type="md5">#{checksum}</checksum>
                  <size>#{size}</size>
                </data_file>
              </asset>
            </software_assets>
          </package>
        }
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
  c.option '-i', '--apple-id STRING', "Apple ID from iTunes Connect"
  c.option '--sdk SDK', "SDK to use when validating the ipa. Defaults to 'iphoneos'"
  c.option '--save-keychain', "Save the provided account in the keychain for future use"

  c.action do |args, options|
    options.default :upload => false, :sdk => 'iphoneos', :save_keychain => true

    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_itunes_connect_account! unless @account = options.account || ENV['ITUNES_CONNECT_ACCOUNT']
    say_error "Missing iTunes Connect account" and abort unless @account

    apple_id = options.apple_id
    say_error "Missing Apple ID" and abort unless apple_id

    @password = options.password || ENV['ITUNES_CONNECT_PASSWORD']
    if @password.nil? && @password = Security::GenericPassword.find(:s => Shenzhen::Plugins::ITunesConnect::ITUNES_CONNECT_SERVER, :a => @account)
      @password = @password.password
      say_ok "Found password in keychain for account: #{@account}" if options.verbose
    else
      determine_itunes_connect_password! unless @password
      say_error "Missing iTunes Connect password" and abort unless @password

      Security::GenericPassword.add(Shenzhen::Plugins::ITunesConnect::ITUNES_CONNECT_SERVER, @account, @password, {:U => nil}) if options.save_keychain
    end

    unless /^[0-9a-zA-Z]*$/ === @password
      say_warning "Password contains special characters, which may not be handled properly by iTMSTransporter. If you experience problems uploading to iTunes Connect, please consider changing your password to something with only alphanumeric characters."
    end

    parameters = []
    parameters << :warnings if options.warnings
    parameters << :errors if options.errors

    client = Shenzhen::Plugins::ITunesConnect::Client.new(@file, apple_id, options.sdk, @account, @password, parameters)

    client.upload_build!
    say_ok "Upload complete."
    say_warning "You may want to double check iTunes Connect to make sure it was received correctly."
  end

  private

  def determine_itunes_connect_account!
    @account ||= ask "iTunes Connect account:"
  end

  def determine_itunes_connect_password!
    @password ||= password "iTunes Connect password:"
  end
end
