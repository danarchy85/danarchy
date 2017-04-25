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

  opts.on('-k', '--keepalive', 'Ensure Redmine is Running') do
    options[:action] = 'keepalive'
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
      cmd = "cd #{@app_path} ; bundle exec puma -C #{@app_path}/config/puma.rb -e production"
      IO.popen(cmd) { |io| io.each_line { |l| puts l } }
      puts 'Waiting while Redmine starts...'
      sleep(10)
      pidstatus = status
    end

    return 1 unless pidstatus
    pidstatus        
  end

  def stop
    pidstatus = status
    return if !pidstatus
    pid = pidstatus[:Pid]
    puts "Stopping Redmine PID: #{pid}..."
    IO.popen("kill #{pid}") { |io| io.each_line { |l| puts l } }
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

unless %w[status start stop restart keepalive].include? ARGV.first
  puts "Usage: #{$PROGRAM_NAME} [status|start|stop|restart|keepalive] "
  exit 1
end

case ARGV.first
when 'status'
  pidstatus = r.status
  puts 'Redmine is not running' if pidstatus == false
when 'start'
  r.start
when 'stop'
  r.stop
when 'restart'
  r.restart
when 'keepalive'
  puts 'Not yet implemented!'
  # r.keepalive
end
