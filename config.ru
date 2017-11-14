require 'sass/plugin/rack'
use Sass::Plugin::Rack

require './app'
run Sinatra::Application
