#!/usr/bin/env ruby
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
    return false if !pid
    # return false unless File.exist?(@pidfile) && File.exist?("/proc/#{pid}/status")
    pidstatus = {}
    File.open("/proc/#{pid}/status").each do |sl|
      k = sl.split(' ')[0].sub(':', '')
      v = sl.split(' ')[1].sub(':', '')
      pidstatus[:"#{k}"] = v
    end

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
    pidstatus = start

    if pidstatus
      puts "Redmine is running as PID: #{pidstatus[:Pid]}"
    else
      puts 'Redmine failed to restart!'
    end
  end

  def monitor
    log = "#{@app_path}/log/puma_redmine_init.log"
    restarts = 0

    fork do
      $stdin.reopen '/dev/null'
      $stdout.reopen log
      $stderr.reopen log
      trap(:HUP) do
        puts 'Ignoring SIGHUP'
      end
      trap(:TERM) do
        puts 'Exiting Puma/Redmine'
        exit
      end
      loop do
        t = Time.now.strftime("%Y/%m/%d %H:%M")
        pidstatus = status

        if pidstatus == false
          start
          restarts += 1

          File.open(log, 'a') do |log|
            entry = "Restarted Redmine: #{t}"
            log.puts entry
          end
        else
          File.open(log, 'a') do |log|
            entry = "Redmine is running: #{t}"
            log.puts entry
          end

          sleep(900)
        end
      end
    end
  end
end

r = Redmine.new

unless %w[status start stop restart monitor].include? ARGV.first
  puts "Usage: #{$PROGRAM_NAME} [status|start|stop|restart|monitor] "
  exit 1
end

case ARGV.first
when 'status'
  pidstatus = r.status

  if pidstatus
    puts "Redmine is running as PID: #{pidstatus[:Pid]}"
  else
    puts 'Redmine is not running!'
  end
when 'start'
  r.start
when 'stop'
  r.stop
when 'restart'
  r.restart
when 'monitor'
  r.monitor
end
