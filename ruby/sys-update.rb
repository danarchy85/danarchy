#!/usr/bin/env ruby
require 'optparse'
require 'socket'

server_vars = {
  server_hostname: 'local_hostname',
  server_domain: 'FQDN',
  server_lan_ip: 'local_IP',
  server_user: 'user with read access to server:/usr/portage',
  sys_update_path: '/server/path/to/sys-update.rb',
  ssh_key_path: '/home/user/.ssh/id_ed25519',
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
    version = '1.2.15'
  end
  
  def self.version_update(server_vars)
    ssh_key = server_vars[:ssh_key_path]
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
  def initialize(targethost, targetuser, ssh_exec, options)
    (@targethost, @targetuser, @ssh_exec) = targethost, targetuser, ssh_exec
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
    opts.push("--rsh #{@ssh_exec}")

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
    path = '/usr/portage'
    puts "Mounting: #{targethost}:#{path}"
    system("mount -o noatime -t nfs #{targethost}:#{path} #{path}")
  end

  def umount_nfs
    path = '/usr/portage'
    File.readlines('/etc/fstab').grep(/\/usr\/portage/).each do |l|
      if l.include?('defaults,auto')
        puts "Leaving #{path} mounted."
      elsif l.include?('defaults,noauto')
        puts "Unmounting: #{path}"
        system("umount -v #{path}")
      else
        raise "Unknown #{path} entry in /etc/fstab"
      end
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
  abort('Must run with sudo') unless Process.uid == 0

  # Determine location for whether to mount NFS or sync
  loc = Location.new server_vars
  localhost = loc.localhost
  targethost = loc.targethost
  targetuser = loc.targetuser
  ssh_exec = "\'ssh -i #{server_vars[:ssh_key_path]}\'"

  targethost = server_vars[:server_domain] if options[:public] == true
  targethost = server_vars[:server_hostname] if options[:local] == true
  
  e = Emerge.new targethost, targetuser, ssh_exec, options
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
