require 'pathname'

module Shenzhen::Plugins
  module Crashlytics
    class Client

      def initialize(crashlytics_path, api_token, build_secret)
        @api_token, @build_secret = api_token, build_secret

        @crashlytics_path = Pathname.new("#{crashlytics_path}/submit").cleanpath.to_s
        say_error "Path to Crashlytics.framework/submit is invalid" and abort unless File.exists?(@crashlytics_path)
      end

      def upload_build(ipa, options)
        command = "#{@crashlytics_path} #{@api_token} #{@build_secret} -ipaPath '#{options[:file]}'"
        command += " -notesPath '#{options[:notes]}'" if options[:notes]
        command += " -emails #{options[:emails]}" if options[:emails]
        command += " -groupAliases #{options[:groups]}" if options[:groups]
        command += " -notifications #{options[:notifications] ? 'YES' : 'NO'}"

        system command
      end
    end
  end
end

command :'distribute:crashlytics' do |c|
  c.syntax = "ipa distribute:crashlytics [options]"
  c.summary = "Distribute an .ipa file over Crashlytics"
  c.description = ""
  c.option '-c', '--crashlytics_path PATH', "/path/to/Crashlytics.framework/"
  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-a', '--api_token TOKEN', "API Token. Available at https://www.crashlytics.com/settings/organizations"
  c.option '-s', '--build_secret SECRET', "Build Secret. Available at https://www.crashlytics.com/settings/organizations"
  c.option '-m', '--notes PATH', "Path to release notes file"
  c.option '-e', '--emails EMAIL1,EMAIL2', "Emails of users for access"
  c.option '-g', '--groups GROUPS', "Groups for users for access"
  c.option '-n', '--notifications [YES | NO]', "Should send notification email to testers?"

  c.action do |args, options|
    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_crashlytics_path! unless @crashlytics_path = options.crashlytics_path || ENV['CRASHLYTICS_FRAMEWORK_PATH']
    say_error "Missing path to Crashlytics.framework" and abort unless @crashlytics_path

    determine_crashlytics_api_token! unless @api_token = options.api_token || ENV['CRASHLYTICS_API_TOKEN']
    say_error "Missing API Token" and abort unless @api_token

    determine_crashlytics_build_secret! unless @build_secret = options.build_secret || ENV['CRASHLYTICS_BUILD_SECRET']
    say_error "Missing Build Secret" and abort unless @build_secret

    parameters = {}
    parameters[:file] = @file
    parameters[:notes] = options.notes if options.notes
    parameters[:emails] = options.emails if options.emails
    parameters[:groups] = options.groups if options.groups
    parameters[:notifications] = options.notifications == 'YES' if options.notifications

    client = Shenzhen::Plugins::Crashlytics::Client.new(@crashlytics_path, @api_token, @build_secret)

    if client.upload_build(@file, parameters)
      say_ok "Build successfully uploaded to Crashlytics"
    else
      say_error "Error uploading to Crashlytics" and abort
    end
  end

  private

  def determine_crashlytics_path!
    @crashlytics_path ||= ask "Path to Crashlytics.framework:"
  end

  def determine_crashlytics_api_token!
    @api_token ||= ask "API Token:"
  end

  def determine_crashlytics_build_secret!
    @build_secret ||= ask "Build Secret:"
  end
end
