$:.push File.expand_path('../', __FILE__)

require 'plugins/testflight'
require 'plugins/hockeyapp'
require 'plugins/ftp'
require 'plugins/s3'

require 'commands/build'
require 'commands/distribute'
require 'commands/info'
