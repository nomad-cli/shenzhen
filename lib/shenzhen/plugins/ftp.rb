require 'net/ftp'

module Shenzhen::Plugins
  module FTP
    class Client

      def initialize(host, user, pass)
        @host, @user, @pass = host, user, pass
        @connection = Net::FTP.new
        @connection.passive = true
        @connection.connect(@host)
      end

      def upload_build(files, options)

        @ipa_path = files[:ipa]
        @dsym_path = files[:dsym]
        @ftp_path = get_path_from_ipa(@ipa_path, options[:path])

        @connection.login(@user, @pass) rescue raise "Login authentication failed"

        if options[:mkdir]
          paths = @ftp_path.split('/')
          (1..paths.size).each do |i|
            begin
              path = paths.slice(0,i).join('/')
              next if path == ""
              @connection.mkdir path
            rescue => exception
              if !exception.to_s.match(/File exists/)
                  raise "Can not create folder \"#{path}\". FTP exception: #{exception}"
              end
            end
          end
        end

        begin
          @connection.chdir @ftp_path
        rescue => exception
          raise "Can not enter folder \"#{@ftp_path}\". FTP exception: #{exception}"
        end

        begin
          @connection.putbinaryfile(@ipa_path,File.basename(@ipa_path))
        rescue => exception
          raise "Error while uploading ipa file to path \"#{@ftp_path}\". FTP exception: #{exception}"
        end

        if @dsym_path
          begin
            @connection.putbinaryfile(@dsym_path,File.basename(@dsym_path))
          rescue => exception
            raise "Error while uploading dsym file to path \"#{@ftp_path}\". FTP exception: #{exception}"
          end          
        end

        ensure
          @connection.close

      end

      def get_path_from_ipa(ipa, path)

        plist_regex = Regexp.new "({(CFBundle[^}]+)})"
        if plist_regex.match path

          # unzip the ipa file to a temp dir in order to read its Info.plist file
          tmp_dir = "#{Dir.tmpdir}/ShenzhenFtp"
          system "rm -rf #{tmp_dir}; mkdir #{tmp_dir}; unzip -q #{ipa} -d #{tmp_dir} 2> /dev/null"
          
          # replace all occurences of {CFBundle***} from the plist file to use with the path
          path.gsub!(plist_regex) do
            output = `/usr/libexec/PlistBuddy -c \"Print :#{$2}\" #{tmp_dir}/Payload/*.app/Info.plist 2> /dev/null`.chomp
            output.size == 0 || /Does Not Exist/.match(output) ? $1 : output
          end

          system "rm -rf #{tmp_dir}"

        end

        path

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
  c.option '-h', '--host HOST', "FTP Host"
  c.option '-u', '--user USER', "FTP user"
  c.option '-p', '--pass PASS', "FTP password"
  c.option '-P', '--path PATH', "FTP Path. Might have any Info.plist params \n\t\t eg. \"/path/to/folder/{CFBundleVersion}/\" will be evaluated as \"/path/to/folder/1.0.0/\" depending on your ipa file"
  c.option '-m', '--mkdir', "Folder tree will be created at the ftp server if it doesn't exist"
  c.option '-q', '--quiet', "Silence warning and success messages"


  c.action do |args, options|

    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_dsym! unless @dsym = options.dsym
    say_error "Specified dSYM.zip file doesn't exist" if @dsym and !File.exist?(@dsym)

    @host = options.host
    say_error "Missing FTP host" and abort unless @host

    determine_user! unless @user = options.user
    say_error "Missing FTP user" and abort unless @user

    determine_pass! unless @pass = options.pass
    say_error "Missing FTP password" and abort unless @pass

    @path = options.path
    say_error "Missing FTP Path" and abort unless @path

    parameters = {}
    parameters[:path] = @path
    parameters[:mkdir] = options.mkdir ? true : false

    client = Shenzhen::Plugins::FTP::Client.new @host, @user, @pass

    files = {}
    files[:ipa] = @file
    files[:dsym] = @dsym if @dsym

    begin
      client.upload_build files, parameters
      say_ok "Build successfully uploaded to FTP" unless options.quiet
    rescue => exception
      say_error "Error while uploading to FTP: #{exception}"
    end

  end

  private

  def determine_user!
    @user ||= ask "Ftp user:"
  end

  def determine_pass!
    @pass ||= ask("Ftp password:"){ |q| q.echo = "*" }
  end

end