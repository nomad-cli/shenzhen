$:.push File.expand_path('../', __FILE__)

require 'plugins/testflight'
require 'plugins/hockeyapp'
require 'plugins/ftp'
require 'plugins/api'

require 'commands/build'
require 'commands/distribute'

