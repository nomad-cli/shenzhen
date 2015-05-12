require 'aws-sdk'

module Shenzhen::Plugins
  module S3
    class Client
      def initialize(access_key_id, secret_access_key, region)
        @s3 = AWS::S3.new(:access_key_id => access_key_id,
          :secret_access_key => secret_access_key,
          :region => region)
      end

      def upload_build(ipa, options)
        path = expand_path_with_substitutions_from_ipa_plist(ipa, options[:path]) if options[:path]

        @s3.buckets.create(options[:bucket]) if options[:create]

        bucket = @s3.buckets[options[:bucket]]

        uploaded_urls = []

        files = []
        files << ipa
        options[:dsyms].each { |dsym| files << dsym } if options[:dsyms]
        files.each do |file|
          basename = File.basename(file)
          key = path ? File.join(path, basename) : basename
          File.open(file) do |descriptor|
            obj = bucket.objects.create(key, descriptor, :acl => options[:acl])
            uploaded_urls << obj.public_url.to_s
          end
        end

        uploaded_urls
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
end

command :'distribute:s3' do |c|
  c.syntax = "ipa distribute:s3 [options]"
  c.summary = "Distribute an .ipa file over Amazon S3"
  c.description = ""

  c.example '', '$ ipa distribute:s3 -f ./file.ipa -a accesskeyid --bucket bucket-name'

  c.option '-f', '--file FILE', ".ipa file for the build"
  c.option '-d', '--dsym FILES', Array, "Comma separated list of .dSYM.zip packages for the build"
  c.option '-a', '--access-key-id ACCESS_KEY_ID', "AWS Access Key ID"
  c.option '-s', '--secret-access-key SECRET_ACCESS_KEY', "AWS Secret Access Key"
  c.option '-b', '--bucket BUCKET', "S3 bucket"
  c.option '--[no-]create', "Create bucket if it doesn't already exist"
  c.option '-r', '--region REGION', "Optional AWS region (for bucket creation)"
  c.option '--acl ACL', "Uploaded object permissions e.g public_read (default), private, public_read_write, authenticated_read"
  c.option '--source-dir SOURCE', "Optional source directory e.g. ./build"
  c.option '-P', '--path PATH', "S3 'path'. Values from Info.plist will be substituded for keys wrapped in {}  \n\t\t eg. \"/path/to/folder/{CFBundleVersion}/\" could be evaluated as \"/path/to/folder/1.0.0/\""

  c.action do |args, options|
    Dir.chdir(options.source_dir) if options.source_dir

    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_dsyms! unless @dsyms = options.dsym
    say_error "Specified dSYM.zip files don't exist" if @dsyms and @dsyms.any? { |dsym| !File.exist?(dsym) }

    determine_access_key_id! unless @access_key_id = options.access_key_id
    say_error "Missing AWS Access Key ID" and abort unless @access_key_id

    determine_secret_access_key! unless @secret_access_key = options.secret_access_key
    say_error "Missing AWS Secret Access Key" and abort unless @secret_access_key

    determine_bucket! unless @bucket = options.bucket
    say_error "Missing bucket" and abort unless @bucket

    determine_region! unless @region = options.region

    determine_acl! unless @acl = options.acl
    say_error "Missing ACL" and abort unless @acl

    @path = options.path

    client = Shenzhen::Plugins::S3::Client.new(@access_key_id, @secret_access_key, @region)

    begin
      urls = client.upload_build @file, {:bucket => @bucket, :create => !!options.create, :acl => @acl, :dsyms => @dsyms, :path => @path}
      urls.each { |url| say_ok url}
      say_ok "Build successfully uploaded to S3"
    rescue => exception
      say_error "Error while uploading to S3: #{exception}"
    end
  end

  private

  def determine_access_key_id!
    @access_key_id ||= ENV['AWS_ACCESS_KEY_ID']
    @access_key_id ||= ask "Access Key ID:"
  end

  def determine_secret_access_key!
    @secret_access_key ||= ENV['AWS_SECRET_ACCESS_KEY']
    @secret_access_key ||= ask "Secret Access Key:"
  end

  def determine_bucket!
    @bucket ||= ENV['S3_BUCKET']
    @bucket ||= ask "S3 Bucket:"
  end

  def determine_region!
    @region ||= ENV['AWS_REGION']
  end

  def determine_acl!
    @acl ||= "public_read"
  end
end
