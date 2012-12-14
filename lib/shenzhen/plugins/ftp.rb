require 'net/ftp'

module Shenzhen::Plugins
  module FTP
    class Client

      def initialize(host, user, pass)
        @host, @user, @password = host, user, pass

        @connection = Net::FTP.new
        @connection.passive = true
        @connection.connect(@host)
      end

      def upload_build(ipa, options)
        path = expand_path_with_substitutions_from_ipa_plist(ipa, options[:path])

        begin
          @connection.login(@user, @password) rescue raise "Login authentication failed"

          if options[:mkdir]
            components, pwd = path.split(/\//), nil
            components.each do |component|
              pwd = File.join(*[pwd, component].compact)

              begin
                @connection.mkdir pwd
              rescue => exception
                raise exception unless /File exists/ === exception.message
              end
            end
          end

          @connection.chdir path unless path.empty?
          @connection.putbinaryfile ipa, File.basename(ipa)

          if dsym = options.delete(:dsym)
            @connection.putbinaryfile dsym, File.basename(dsym)
          end

        ensure
          @connection.close
        end
      end

      private

      def expand_path_with_substitutions_from_ipa_plist(ipa, path)
        components = []

        substitutions = path.scan(/\{CFBundle[^}]+\}/)
        return path if substitutions.empty?

        Dir.mktmpdir do |dir|
          system "unzip -q #{ipa} -d #{dir} 2> /dev/null"

          plist = Dir["#{dir}/**/Info.plist"].last

          substitutions.uniq.each do |substitution|
            key = substitution[1...-1]
            value = Shenzhen::PlistBuddy.print(plist, key)

            path.gsub!(Regexp.new(substitution), value) if value
          end
        end

        return path
      end
    end
  end
end

command :'distribute:ftp' do |c|
  c.syntax = "ipa distribute:ftp [options]"
  c.summary = "Distribute an .ipa file over FTP"
  c.description = ""

  c.example '', '$ ipa distribute:ftp --host 127.0.0.1 -f ./file.ipa -u username --path "/path/to/folder/{CFBundleVersion}/" --mkdir'

  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-d', '--dsym FILE', "zipped .dsym package for the build"
  c.option '-h', '--host HOST', "FTP host"
  c.option '-u', '--user USER', "FTP user"
  c.option '-p', '--password PASS', "FTP password"
  c.option '-P', '--path PATH', "FTP path. Values from Info.plist will be substituded for keys wrapped in {}  \n\t\t eg. \"/path/to/folder/{CFBundleVersion}/\" could be evaluated as \"/path/to/folder/1.0.0/\""
  c.option '--[no-]mkdir', "Create directories on FTP if they don't already exist"

  c.action do |args, options|

    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_dsym! unless @dsym = options.dsym
    say_error "Specified dSYM.zip file doesn't exist" unless @dsym and File.exist?(@dsym)

    determine_host! unless @host = options.host
    say_error "Missing FTP host" and abort unless @host

    determine_user! unless @user = options.user
    say_error "Missing FTP user" and abort unless @user

    determine_password! unless @password = options.password
    say_error "Missing FTP password" and abort unless @password

    @path = options.path || ""

    client = Shenzhen::Plugins::FTP::Client.new(@host, @user, @password)

    begin
      client.upload_build @file, {:path => @path, :dsym => @dsym, :mkdir => !!options.mkdir}
      say_ok "Build successfully uploaded to FTP" unless options.quiet
    rescue => exception
      say_error "Error while uploading to FTP: #{exception}"
    end
  end

  private

  def determine_host!
    @host ||= ask "FTP Host:"
  end

  def determine_user!
    @user ||= ask "Username:"
  end

  def determine_password!
    @password ||= password "Password:"
  end
end
