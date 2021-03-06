lib_dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)
require "freec_base"
require 'listener'

require 'fileutils'
require 'daemons/daemonize'
include Daemonize

def freec_app_file_name
  $0.sub(/\.[^\.]*$/, '')  
end

def freec_app_class_name
  freec_app_file_name.split('_').map{|w| w.capitalize}.join
end

def freec_app_log_dir
  "#{ROOT}/log"
end

def create_freec_app_log_dir
  FileUtils.mkdir_p(freec_app_log_dir)  
end

def freec_app_log_file
  @@log_file ||= "#{freec_app_log_dir}/#{freec_app_file_name}.log"
end

def freec_app_pid_file
  "#{freec_app_log_dir}/#{freec_app_file_name}.pid"
end

def load_freec_app_config
  if File.exist?(freec_app_configuration_file)
    @@config = YAML.load_file(freec_app_configuration_file)
  else
    @@config = {}
  end
  @@config['listen_port'] ||= '8084' 
end

def freec_app_configuration_file
  "#{ROOT}/config/config.yml"
end


unless defined?(TEST)
  ROOT = File.expand_path(File.dirname($0))
  ENVIRONMENT = ARGV[0] == '-d' ? 'production' : 'development'
  create_freec_app_log_dir
  load_freec_app_config
  
  # Daemonize as soon as possible to make rails inclusion and other stuff work
  if ARGV[0] == '-d'
    puts 'Daemonizing...'
    daemonize(freec_app_log_file)
    Dir.chdir(ROOT)
  end

  at_exit do
    open(freec_app_pid_file, "w") {|f| f.write(Process.pid) }

    server = Listener.new('127.0.0.1', @@config['listen_port'].to_i, freec_app_class_name)
    server.audit = true
    server.start
    puts "Listening on port #{@@config['listen_port']}"
    loop do
      break if server.stopped?
      sleep(1)
    end
  end
end
