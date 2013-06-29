require 'aws-sdk'

module Shenzhen::Plugins
  module S3
    class Client

      def initialize(access_key_id, secret_access_key, region)
        @s3 = AWS::S3.new(
            :access_key_id => access_key_id,
            :secret_access_key => secret_access_key,
            :region => region)
      end

      def upload_build(ipa, options)
        @s3.buckets.create(options[:bucket]) if options[:create]

        bucket = @s3.buckets[options[:bucket]]

        bucket.objects.create(ipa, File.open(ipa), :acl => options[:acl])

        if dsym = options.delete(:dsym)
          bucket.objects.create(dsym, File.open(dsym), :acl => options[:acl])
        end
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
  c.option '-d', '--dsym FILE', "zipped .dsym package for the build"
  c.option '-a', '--access-key-id ACCESS_KEY_ID', "AWS Access Key ID"
  c.option '-s', '--secret-access-key SECRET_ACCESS_KEY', "AWS Secret Access Key"
  c.option '-b', '--bucket BUCKET', "S3 bucket"
  c.option '--[no-]create', "Create bucket if it doesn't already exist"
  c.option '-r', '--region REGION', "Optional AWS region (for bucket creation)"
  c.option '--acl ACL', "Object permissions e.g private (default), public_read, public_read_write, authenticated_read"

  c.action do |args, options|

    determine_file! unless @file = options.file
    say_error "Missing or unspecified .ipa file" and abort unless @file and File.exist?(@file)

    determine_dsym! unless @dsym = options.dsym
    say_error "Specified dSYM.zip file doesn't exist" unless @dsym and File.exist?(@dsym)

    determine_access_key_id! unless @access_key_id = options.access_key_id
    say_error "Missing AWS Access Key ID" and abort unless @access_key_id

    determine_secret_access_key! unless @secret_access_key = options.secret_access_key
    say_error "Missing AWS Secret Access Key" and abort unless @secret_access_key

    determine_bucket! unless @bucket = options.bucket
    say_error "Missing bucket" and abort unless @bucket

    determine_region! unless @region = options.region
    say_error "Missing region" and abort unless @region

    determine_acl! unless @acl = options.acl
    say_error "Missing acl" and abort unless @acl

    client = Shenzhen::Plugins::S3::Client.new(@access_key_id, @secret_access_key, @region)

    begin
      client.upload_build @file, {:bucket => @bucket, :create => !!options.create, :acl => @acl, :dsym => @dsym}
      say_ok "Build successfully uploaded to S3" unless options.quiet
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
    @secret_access_key ||= secret_access_key "Secret Access Key:"
  end

  def determine_bucket!
    @bucket ||= ask "S3 Bucket:"
  end

  def determine_region!
    @region ||= ENV['AWS_REGION']
    @region ||= ""
  end

  def determine_acl!
    @acl ||= "private"
  end  
end
