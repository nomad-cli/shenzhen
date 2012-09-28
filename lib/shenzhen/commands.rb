$:.push File.expand_path('../', __FILE__)

require 'plugins/testflight'
require 'plugins/hockeyapp'

require 'commands/build'
require 'commands/distribute'

