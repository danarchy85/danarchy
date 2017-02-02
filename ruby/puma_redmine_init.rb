#!/usr/bin/env ruby
require 'optparse'
require 'open3'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [status|start|stop]"

  opts.on('--status', 'View Status of Running Redmine') do
    options[:action] = 'status'
  end

  opts.on('--start', 'Start up Redmine') do
    options[:action] = 'start'
  end

  opts.on('--stop', 'Stop Redmine if Running') do
    options[:action] = 'stop'
  end

  opts.on('--restart', 'Restart Redmine') do
    options[:action] = 'restart'
  end

  opts.on('-k', '--keeprunning', 'Ensure Redmine is Running') do
    options[:action] = 'keeprunning'
  end

  opts.on('-h', '--help', 'print this usage information') do
    puts opts
    exit
  end
end.parse!

# Redmine Init Handler
class Redmine
  def initialize
    user = 'redmine'
    app = 'redmine'
    @app_path = "/home/#{user}/#{app}"
    @pidfile = "#{@app_path}/tmp/pids/puma.pid"
  end

  def status
    pid = File.read(@pidfile).chomp if File.exist?(@pidfile)
    return false unless File.exist?(@pidfile) && File.exist?("/proc/#{pid}/status")
    pidstatus = {}
    File.open("/proc/#{pid}/status").each do |sl|
      k = sl.split(' ')[0].sub(':', '')
      v = sl.split(' ')[1].sub(':', '')
      pidstatus[:"#{k}"] = v
    end

    puts 'Redmine is not running' if !pidstatus
    puts "Redmine is running as PID: #{pidstatus[:Pid]}" if pidstatus
    return pidstatus if pidstatus[:Pid] == pid
  end

  def start
    pidstatus = status
    if pidstatus == false
      puts 'Starting Redmine...'
      exec_start = IO.popen("cd #{@app_path} ; bundle exec puma -C #{@app_path}/config/puma.rb -e production")
      exec_start.each { |exec| puts exec }
      puts 'Waiting while Redmine starts...'
      sleep(15)
      pidstatus = status
    end

    return 1 unless pidstatus
  end

  def stop
    pidstatus = status
    return if !pidstatus
    pid = pidstatus[:Pid]
    puts "Stopping Redmine PID: #{pid}..."
    exec_stop = IO.popen("kill #{pid}")
    exec_stop.each { |exec| puts exec }
    sleep(3)
    if status == false
      puts "Redmine PID: #{pid} has stopped"
    else
      puts "Redmine PID: #{pid} is still running!"
      return 1
    end
  end

  def restart
    puts 'Restarting Redmine...'
    stop
    start
  end
end

r = Redmine.new

puts "Redmine: #{options[:action]}"

if options[:action] == 'status'
  pidstatus = r.status
elsif options[:action] == 'start'
  r.start
elsif options[:action] == 'stop'
  r.stop
elsif options[:action] == 'restart'
  r.restart
elsif options[:action] == 'keeprunning'
  pidstatus = r.status
  r.restart if pidstatus == false
end
