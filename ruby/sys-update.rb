#!/usr/bin/env ruby
require 'optparse'
require 'socket'

server_vars = {
  server_hostname: 'server_hostname',
  server_domain: 'server_domain',
  server_lan_ip: 'server_lan_ip',
  server_user: 'server_user',
}

options = {
  ask: true,
  sync: true,
  verbose: true,
}

OptionParser.new do |opts|
  opts.banner = "Usage: sudo #{$PROGRAM_NAME} [options]"

  opts.on('-i', '--insist', 'Dont --ask') do |value|
    options[:ask] = false
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
  def initialize(server_vars)
    @server_vars = server_vars
    begin
      Socket.tcp(@server_vars[:server_lan_ip], 22, connect_timeout: 5)
      @connection = true
    rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      @connection = false
    end
  end

  def localhost
    Socket.gethostname
  end

  def targethost
    return @server_vars[:server_lan_ip] if @connection == true
    @server_vars[:server_domain]
  end

  def targetuser
    @server_vars[:server_user]
  end
end

class Emerge
  def initialize(targethost, targetuser, options)
    @targethost = targethost
    @targetuser = targetuser
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
    puts "Running: rsync #{rsync_opts} #{@rsync_opts} #{@targetuser}@#{@targethost}:/usr/portage /usr/portage"
    system("rsync #{@rsync_opts} #{rsync_opts} #{@targetuser}@#{@targethost}:/usr/portage/ /usr/portage/")
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
  def mount_nfs(targethost)
    puts "Mounting: #{targethost}:/usr/portage"
    system("mount -t nfs #{targethost}:/usr/portage /usr/portage")
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

  loc = Location.new server_vars
  localhost = loc.localhost
  targethost = loc.targethost
  targetuser = loc.targetuser
  
  e = Emerge.new targethost, targetuser, options
  n = NFS.new
  
  if localhost == server_vars[:server_hostname]
    puts "Localhost is #{localhost}"
    e.emerge_sync if options[:sync]
    e.emerge
    e.depclean
  elsif targethost == server_vars[:server_lan_ip]
    puts "#{localhost} is within the network"
    n.mount_nfs(targethost)
    e.emerge
    e.depclean
    n.umount_nfs
  else
    puts "#{localhost} is outside of the network"
    e.rsync unless !options[:sync]
    e.emerge
    e.depclean
  end
end

