#!/usr/bin/env ruby
require 'optparse'
require 'socket'

server_vars = {
  server_hostname: 'local_hostname',
  server_domain: 'FQDN',
  server_lan_ip: 'local_IP',
  server_user: 'user with access to /usr/portage',
  sys_update_path: '/server/path/to/sys-update.rb',
}

options = {
  sync: true,
  verbose: true,
  ask: true,
  depclean: false,
  local: false,
  public: false,
}

class SysUpdate
  def self.version
    version = '1.2.5'
  end
  
  def self.version_update(server_vars)
    ssh_key = File.join('/home', server_vars[:server_user], '/.ssh/id_ed25519')
    @connection = "#{server_vars[:server_user]}@#{server_vars[:server_domain]}"
    @sys_update_path = server_vars[:sys_update_path]
    latest = `ssh -i #{ssh_key} #{@connection} /usr/bin/ruby #{@sys_update_path} --version`

    puts "Current version: #{version}"
    puts "Latest version: #{latest}"
    if Gem::Version.new(latest) > Gem::Version.new(version)
      print "Updating #{File.basename(__FILE__)}:#{version} to #{latest}\n"
      bindir = File.dirname(__FILE__)
      download = "scp -i #{ssh_key} #{@connection}:#{@sys_update_path} #{bindir}/"
      system(download)
    end
  end
end

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
    (@targethost, @targetuser) = targethost, targetuser
    @options = options
  end
  
  def emerge_sync
    opts = '--quiet' unless @options[:verbose]
    cmd = "emerge --sync #{opts}"
    puts "Running: #{cmd}"
    system(cmd)
  end

  def rsync
    opts = %w[--recursive --links --perms --times --devices --delete --timeout=300 --exclude=distfiles/ --exclude=packages/]
    opts.push('--verbose') if @options[:verbose]
    cmd = "rsync #{opts.join(' ')} #{@targetuser}@#{@targethost}:/usr/portage/ /usr/portage/"
    puts "Running: #{cmd}"
    system(cmd)
  end

  def emerge
    opts = %w[--update --deep --newuse --with-bdeps=y @world]
    opts.push('--verbose') if @options[:verbose]
    opts.push('--ask') if @options[:ask]
    cmd = "emerge #{opts.join(' ')}"
    puts "Running: #{cmd}"
    system(cmd)
  end

  def depclean
    opts = %w[--depclean]
    opts.push('--verbose') if @options[:verbose]
    opts.push('--ask') if @options[:ask]
    cmd = "emerge #{opts.join(' ')}"
    puts "Running: #{cmd}"
    system(cmd)
  end
end

class NFS
  def mount_nfs(targethost)
    puts "Mounting: #{targethost}:/usr/portage/distfiles"
    system("mount -t nfs #{targethost}:/usr/portage /usr/portage/distfiles")
  end

  def umount_nfs
    unless File.read('/etc/fstab').include?('/usr/portage/distfiles')
      puts "Unmounting: /usr/portage/distfiles"
      system('umount /usr/portage/distfiles')
    end
  end
end

OptionParser.new do |opts|
  opts.banner = "Usage: sudo #{$PROGRAM_NAME} [options]"

  opts.on('-g', '--go', 'Don\'t --ask, just go!') do |value|
    options[:ask] = false
  end

  opts.on('-d', '--depclean', 'Run --depclean after emerge') do |value|
    options[:depclean] = true
  end

  opts.on('-q', '--quiet', 'Non verbose output') do |value|
    options[:verbose] = false
  end

  opts.on('-l', '--local', 'Force emerge --sync within LAN') do |value|
    options[:local] = true
  end

  opts.on('-p', '--public', 'Force emerge --sync over public WAN') do |value|
    options[:public] = true
  end

  opts.on('-s', '--skip_sync', 'skips emerge --sync') do |value|
    options[:sync] = false
  end

  opts.on('-V', '--version', 'Version of sys-update.rb') do |value|
    puts SysUpdate.version
    exit
  end

  opts.on('-h', '--help', 'print this usage information') do
    puts opts
    exit
  end
end.parse!

if __NAME__ = $PROGRAM_NAME
  # check if user is root
  raise 'Must run with sudo' unless Process.uid == 0

  # Determine location for whether to mount NFS or sync
  loc = Location.new server_vars
  localhost = loc.localhost
  targethost = loc.targethost
  targetuser = loc.targetuser

  targethost = server_vars[:server_domain] if options[:public] == true
  targethost = server_vars[:server_hostname] if options[:local] == true
  
  e = Emerge.new targethost, targetuser, options
  n = NFS.new

  # Update sys-update.rb if :server_hostname has a new version
  SysUpdate.version_update(server_vars) if localhost != server_vars[:server_hostname]
    
  if localhost == server_vars[:server_hostname]
    puts "Localhost is #{localhost}"
    e.emerge_sync if options[:sync]
    e.emerge
    e.depclean if options[:depclean]
  elsif targethost == server_vars[:server_lan_ip]
    puts "#{localhost} is within the network"
    e.rsync if options[:sync]
    n.mount_nfs(targethost)
    e.emerge
    e.depclean if options[:depclean]
    n.umount_nfs
  else
    puts "#{localhost} is outside of the network"
    e.rsync if options[:sync]
    e.emerge
    e.depclean if options[:depclean]
  end
end
