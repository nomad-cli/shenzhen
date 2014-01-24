require 'pathname'
require 'zip'
require 'tempfile'

command :show do |c|
  c.syntax = 'ipa show [options]'
  c.summary = 'show info about your .ipa file'
  c.description = ''

  c.option '-f', '--ipafile IPAFILE', 'show info about IPAFILE'

  c.action do |args, options|
    @ipafile = options.ipafile
    say_error "file #{@ipafile} not found" and abort if @ipafile.nil?

    if File.extname(@ipafile) != ".ipa"
      say_error "file #{@ipafile} is not an ipa"
    end
    app_name = File.basename(@ipafile, ".ipa")
    MOBILE_PROVISIONING_PATH="Payload/#{app_name}.app/embedded.mobileprovision"

    zipfile = Zip::File.open(@ipafile)

    zipentry = zipfile.find_entry(MOBILE_PROVISIONING_PATH)

    if zipentry.nil?
      say_error "#{MOBILE_PROVISIONING_PATH} is not contained in #{@ipafile}"
      abort
    end

    Zip.continue_on_exists_proc = true
    provisioning_filename = Pathname.new(zipentry.name).split.last.to_s
    provisioning_file = Tempfile.new(provisioning_filename)
    begin
      zipfile.extract(zipentry, provisioning_file.path) {true}
      puts `security cms -D -i #{provisioning_file.path}`
    ensure
      provisioning_file.close
      provisioning_file.unlink
    end
  end
end
