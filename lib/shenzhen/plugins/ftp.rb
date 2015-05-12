require 'net/ftp'
require 'net/sftp'

module Shenzhen::Plugins
  module FTP
    class Client

      def initialize(host, port, user, password)
        @host, @port, @user, @password = host, port, user, password
      end

      def upload(ipa, options = {})
        connection = Net::FTP.new
        connection.passive = true
        connection.connect(@host, @port)

        path = expand_path_with_substitutions_from_ipa_plist(ipa, options[:path])

        begin
          connection.login(@user, @password) rescue raise "Login authentication failed"

          if options[:mkdir]
            components, pwd = path.split(/\//).reject(&:empty?), nil
            components.each do |component|
              pwd = File.join(*[pwd, component].compact)

              begin
                connection.mkdir pwd
              rescue => exception
                raise exception unless /File exists/ === exception.message
              end
            end
          end

          connection.chdir path unless path.empty?
          connection.putbinaryfile ipa, File.basename(ipa)
          if options[:dsyms]
            options[:dsyms].each do |dsym|
              connection.putbinaryfile(dsym, File.basename(dsym))
            end
          end
        ensure
          connection.close
        end
      end

      private

      def expand_path_with_substitutions_from_ipa_plist(ipa, path)
        substitutions = path.scan(/\{CFBundle[^}]+\}/)
        return path if substitutions.empty?

        Dir.mktmpdir do |dir|
          system "unzip -q #{ipa} -d #{dir} 2> /dev/null"

          plist = Dir["#{dir}/**/*.app/Info.plist"].last

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

  module SFTP
    class Client < Shenzhen::Plugins::FTP::Client
      def upload(ipa, options = {})
        session = Net::SSH.start(@host, @user, :password => @password, :port => @port)
        connection = Net::SFTP::Session.new(session).connect!

        path = expand_path_with_substitutions_from_ipa_plist(ipa, options[:path])

        begin
          connection.stat!(path) do |response|
            connection.mkdir! path if options[:mkdir] and not response.ok?

            connection.upload! ipa, determine_file_path(File.basename(ipa), path)
            if options[:dsyms]
              options[:dsyms].each do |dsym|
                connection.upload! dsym, determine_file_path(File.basename(dsym), path)
              end
            end
          end
        ensure
          connection.close_channel
          session.shutdown!
        end
      end

      def determine_file_path(file_name, path)
        if path.empty?
          file_name
        else
          "#{path}/#{file_name}"
        end
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
  c.option '-d', '--dsym FILES', Array, "Comma separated list of .dSYM.zip packages for the build"
  c.option '-h', '--host HOST', "FTP host"
  c.option '-u', '--user USER', "FTP user"
  c.option '-p', '--password PASS', "FTP password"
  c.option '-P', '--path PATH', "FTP path. Values from Info.plist will be substituted for keys wrapped in {}  \n\t\t e.g. \"/path/to/folder/{CFBundleVersion}/\" would be evaluated as \"/path/to/folder/1.0.0/\""
  c.option '--port PORT', "FTP port"
  c.option '--protocol [PROTOCOL]', [:ftp, :sftp], "Protocol to use (ftp, sftp)"
  c.option '--[no-]mkdir', "Create directories on FTP if they don't already exist"

  c.action do |args, options|
    options.default :mkdir => true

    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_dsyms! unless @dsyms = options.dsym
    say_warning "Specified dSYM.zip files don't exist" unless @dsyms and @dsyms.all? { |dsym| File.exist?(dsym) }

    determine_host! unless @host = options.host
    say_error "Missing FTP host" and abort unless @host

    determine_port!(options.protocol) unless @port = options.port

    determine_user! unless @user = options.user
    say_error "Missing FTP user" and abort unless @user

    @password = options.password
    if !@password && options.protocol != :sftp
      determine_password!
      say_error "Missing FTP password" and abort unless @password
    end

    @path = options.path || ""

    client = case options.protocol
             when :sftp
              Shenzhen::Plugins::SFTP::Client.new(@host, @port, @user, @password)
             else
              Shenzhen::Plugins::FTP::Client.new(@host, @port, @user, @password)
             end

    begin
      client.upload @file, {:path => @path, :dsyms => @dsyms, :mkdir => !!options.mkdir}
      say_ok "Build successfully uploaded to FTP"
    rescue => exception
      say_error "Error while uploading to FTP: #{exception}"
      raise if options.trace
    end
  end

  private

  def determine_host!
    @host ||= ask "FTP Host:"
  end

  def determine_port!(protocol)
    @port = case protocol
            when :sftp
              Net::SSH::Transport::Session::DEFAULT_PORT
            else
              Net::FTP::FTP_PORT
            end
  end

  def determine_user!
    @user ||= ask "Username:"
  end

  def determine_password!
    @password ||= password "Password:"
  end
end

alias_command :'distribute:sftp', :'distribute:ftp', '--protocol', 'sftp'
