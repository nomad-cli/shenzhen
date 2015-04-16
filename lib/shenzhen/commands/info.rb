require 'plist'
require 'tempfile'
require 'zip'
require 'zip/filesystem'

command :info do |c|
  c.syntax = 'ipa info [options]'
  c.summary = 'Show mobile provisioning information about an .ipa file'
  c.description = ''

  c.action do |args, options|
    say_error "`security` command not found in $PATH" and abort if `which security` == ""

    determine_file! unless @file = args.pop
    say_error "Missing or unspecified .ipa file" and abort unless @file and ::File.exist?(@file)

    Zip::File.open(@file) do |zipfile|
      app_entry = zipfile.find_entry("Payload/#{File.basename(@file, File.extname(@file))}.app")
      provisioning_profile_entry = zipfile.find_entry("#{app_entry.name}embedded.mobileprovision") if app_entry
      
      if (!provisioning_profile_entry)
        zipfile.dir.entries("Payload").each do |dir_entry|
          if dir_entry =~ /.app$/
            say "Using .app: #{dir_entry}"
            app_entry = zipfile.find_entry("Payload/#{dir_entry}")
            provisioning_profile_entry = zipfile.find_entry("#{app_entry.name}embedded.mobileprovision") if app_entry
            break
          end
        end
      end

      say_error "Embedded mobile provisioning file not found in #{@file}" and abort unless provisioning_profile_entry

      tempfile = Tempfile.new(::File.basename(provisioning_profile_entry.name))
      begin
        zipfile.extract(provisioning_profile_entry, tempfile.path){ override = true }
        plist = Plist::parse_xml(`security cms -D -i #{tempfile.path}`)

        table = Terminal::Table.new do |t|
          plist.each do |key, value|
            next if key == "DeveloperCertificates"

            columns = []
            columns << key
            columns << case value
                       when Hash
                         value.collect{|k, v| "#{k}: #{v}"}.join("\n")
                       when Array
                         value.join("\n")
                       else
                         value.to_s
                       end

            t << columns
          end
        end

        puts table

      rescue => e
        say_error e.message
      ensure
        tempfile.close and tempfile.unlink
      end
    end
  end

  private

  def determine_file!
    files = Dir['*.ipa']
    @file ||= case files.length
              when 0 then nil
              when 1 then files.first
              else
                @file = choose "Select an .ipa File:", *files
              end
  end
end
