$:.push File.expand_path('../', __FILE__)

require 'plugins/rivierabuild'
require 'plugins/hockeyapp'
require 'plugins/testfairy'
require 'plugins/deploygate'
require 'plugins/itunesconnect'
require 'plugins/ftp'
require 'plugins/s3'
require 'plugins/crashlytics'
require 'plugins/fir'
require 'plugins/pgyer'

require 'commands/build'
require 'commands/distribute'
require 'commands/info'
