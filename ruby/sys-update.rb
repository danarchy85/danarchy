#!/usr/bin/env ruby
require 'optparse'
require 'socket'

options = {
  ask: true,
  sync: true,
  verbose: true,
}

OptionParser.new do |opts|
  opts.banner = "Usage: sudo #{$0} [options]"

  opts.on('-i', '--insist', "Don't --ask") do |value|
    options[:ask] == false
  end

  opts.on('-q', '--quiet', 'Non verbose output') do |value|
    options[:verbose] = false
  end

  opts.on('-s', '--skip_sync', 'skips emerge --sync') do |value|
    options[:sync] = false
  end

  opts.on('-h', '--help', 'print this usage information') do
    puts opts
    exit
  end
end.parse!

class Location
  def initialize
    begin
      Socket.tcp("10.0.1.13", 22, connect_timeout: 5)
      @connection = true
    rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      @connection = false
    end
  end

  def localhost
    Socket.gethostname
  end

  def targethost
    '10.0.1.13' if @connection == true
    'danarchy.me'
  end
end

class Emerge
  def initialize(targethost, options)
    @targethost = targethost
    global_opts = []
    global_opts.push('--ask') if options[:ask]
    global_opts.push('--verbose') if options[:verbose]
    @esync_opts = %Q[--quiet] if !options[:verbose]
    @rsync_opts = %Q[--verbose] if options[:verbose]
    @global_opts = global_opts.join(' ')
  end
  
  def emerge_sync
    puts "Running: emerge --sync #{@esync_opts}"
    system("emerge --sync #{@esync_opts}")
  end

  def rsync
    rsync_opts = %Q[--recursive --links --perms --times --devices --delete --timeout=300 --exclude=distfiles/ --exclude=packages/]
    puts "Running: rsync #{rsync_opts} #{@rsync_opts} dan@#{@targethost}:/usr/portage /usr/portage"
    system("rsync #{@rsync_opts} #{rsync_opts} dan@#{@targethost}:/usr/portage/ /usr/portage/")
  end

  def emerge
    emerge_opts = %Q[--update --deep --newuse --with-bdeps=y @world]
    puts "Running: emerge #{@global_opts} #{emerge_opts}"
    system("emerge #{@global_opts} #{emerge_opts}")
  end

  def depclean
    depclean_opts = %Q[--depclean]
    puts "Running: emerge #{depclean_opts} #{@global_opts}"
    system("emerge #{depclean_opts} #{@global_opts}")
  end
end

class NFS
  def mount_nfs
    puts "Mounting: #{@targethost}:/usr/portage"
    system("mount -t nfs #{@targethost}:/usr/portage /usr/portage")
  end

  def umount_nfs
    puts "Unmounting: /usr/portage"
    system('umount /usr/portage')
  end
end

if __NAME__ = $PROGRAM_NAME
  # check if user is root
  raise 'Must run with sudo' unless Process.uid == 0

  emerge_cmd = ARGV.shift
  
  l = Location.new
  localhost = l.localhost
  targethost = l.targethost

  e = Emerge.new targethost, options
  n = NFS.new
  
  if localhost == 'danarchy'
    print "Localhost is #{localhost}"
    e.emerge_sync if options[:sync]
    e.emerge
    e.depclean
  elsif @targethost == '10.0.1.13'
    puts "#{localhost} is within dAnarchy network"
    n.mount_nfs
    e.emerge
    e.depclean
    n.umount_nfs
  else
    puts "#{localhost} is outside of dAnarchy network"
    e.rsync unless !options[:sync]
    e.emerge
    e.depclean
  end
end

