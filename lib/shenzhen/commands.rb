$:.push File.expand_path('../', __FILE__)

require 'plugins/testflight'
require 'plugins/hockeyapp'
require 'plugins/deploygate'
require 'plugins/itunesconnect'
require 'plugins/ftp'
require 'plugins/s3'
require 'plugins/crashlytics'
require 'plugins/firim'
require 'plugins/pgyer'

require 'commands/build'
require 'commands/distribute'
require 'commands/info'
