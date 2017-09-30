#!/usr/bin/env ruby
require 'json'

log = ARGV[0]
abort('Need an Owncloud log file!') if !log || !File.file?(log)
log_arr = File.readlines(log)

log_arr.each do |log|
  JSON.parse(log).each do |key, value|
    if key != 'message'
      printf("%-15s %-5s\n", key, value)
    else
      exception = value.gsub(/(.*Exception: )/, '')
      if exception.include?('Exception')
        JSON.parse(exception).each do |k, v|
          puts "#{k}\t#{v}"
        end
      else
        printf("%-15s %-5s\n", 'Exception: ', exception )
      end
    end
  end
  puts ""      
end
