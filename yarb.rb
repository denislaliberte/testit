#!/usr/bin/env ruby

class Yarb
  def initialize(arguments)
    @data = Hash.new { |h, k| h[k] = {} }
    @data['command']['name'] = arguments.first
  end

  def execute
    return 'Installation instruction' if @data['command']['name'] == 'example'
    return <<~HELP
      Flags
        --help:   output this message

      Commands:
        example:  command to return a example file

    HELP
  end
end

if caller.length == 0
  puts Yarb.new(ARGV).execute
end

