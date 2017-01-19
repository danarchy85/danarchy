#!/usr/bin/env ruby
require 'optparse'
require 'open3'

options = {}

OptionParser.new do |opts|

  opts.banner = "Usage: #{$0} [status|start|stop]"

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

class Redmine
  def initialize
    user = 'redmine'
    app = 'redmine'
    @app_path = "/home/#{user}/#{app}"
    @pidfile = "#{@app_path}/tmp/pids/puma.pid"
  end
  
  def status
    pid = File.read(@pidfile).chomp if File.exists?(@pidfile)
    return false unless File.exists?(@pidfile) && File.exists?("/proc/#{pid}/status")
    pidstatus = {}
    File.open("/proc/#{pid}/status").each do |sl|
      k = sl.split(' ')[0].sub(':','')
      v = sl.split(' ')[1].sub(':','')
      pidstatus[:"#{k}"] = v
    end

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
      puts "Redmine is running as PID: #{pidstatus[:Pid]}"
    else
      puts "Redmine is running as PID: #{pidstatus[:Pid]}"
    end
  end

  def stop
    pidstatus = status
    return puts 'Redmine is not running' if pidstatus == false
    pid = pidstatus[:Pid]
    puts "Stopping Redmine PID: #{pid}..."
    exec_stop = IO.popen("kill #{pid}")
    exec_stop.each { |exec| puts exec }
    sleep(3)
    puts "Redmine PID: #{pid} has stopped" if status == false
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
  if pidstatus == false
    puts "Redmine is not running"
  else
    puts "Redmine is running PID: #{pidstatus[:Pid]}"
  end
elsif options[:action] == 'start'
  r.start
elsif options[:action] == 'stop'
  r.stop
elsif options[:action] == 'restart'
  r.restart
elsif options[:action] == 'keeprunning'
  pidstatus = r.status
  if pidstatus == false
    r.restart
  end
end
