#!/usr/bin/env ruby
require 'optparse'
require 'socket'

options = {
  verbose: (true),
  sync: (true),
}

OptionParser.new do |opts|

  opts.set_program_name($PROGRAM_NAME)
  opts.banner = "Usage: sudo #{opts.program_name} [options]"

  opts.on("-q", "--quiet", "Non verbose output") do |value|
    options[:verbose] = false
  end

  opts.on("-s", "--skip_sync", "skips emerge --sync") do |value|
    options[:sync] = false
  end

  opts.on("-h", "--help", "print this usage information") do
    puts opts
    exit
  end

end.parse!

class Location

  def self.localhost
    localhost = Socket.gethostname
  end

  def self.targethost
    connection = Location.new.connection
    if (connection == true)
      targethost = "10.0.1.13"
    else
      targethost = "danarchy.me"
    end
  end
  
  def connection
    begin
      Socket.tcp("10.0.1.13", 22, connect_timeout: 5)
      true
    rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      false
    end
  end

end

def sync(localhost, targethost, options)
  path = "/usr/portage/"
  if (localhost == "danarchy")
    print "Localhost is ", localhost, ": running emerge --sync\n"
    if !options[:verbose]
      quiet = "--quiet"
    end
    system("emerge --sync #{quiet}")
    puts "emerge --sync finished!"
  else
    print "Localhost is ", localhost, ": rsyncing from ", targethost, "\n"
    rsync_opts = "--recursive --links --perms --times --devices --delete --timeout=300 --exclude=distfiles/ --exclude=packages/"
    if options[:verbose]
      rsync_verbose = "--verbose"
    end
    system("rsync #{rsync_opts} #{rsync_verbose} dan@#{targethost}:#{path} #{path}")
  end
end

def emerge(options)
  if options[:verbose]
    verbose = "--verbose"
  end
  system("emerge -uDNa #{verbose} --with-bdeps=y @world")
  system("emerge -a #{verbose} --depclean")
end

if __NAME__ = $PROGRAM_NAME
  # check if user is root
  raise "Must run with sudo" unless Process.uid == 0

  if options[:sync]
    localhost = Location.localhost
    targethost = Location.targethost
  
    sync(localhost, targethost, options)
    puts "Running emerge..."
    emerge(options)
  else
    puts "Skipping sync..."
    puts "Running emerge..."
    emerge(options)
  end
end

