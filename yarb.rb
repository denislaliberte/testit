#!/usr/bin/env ruby
require 'yaml'

class Yarb
  def initialize(arguments)
    @data = Hash.new { |h, k| h[k] = {} }
    @data['command']['name'] = arguments[0]
    @data['command']['argument'] = arguments[1]
    if  @data['command']['argument']
      @data = merge(YAML.load_file(@data['command']['argument']), @data)
    end
  end

  def execute
    return example if @data['command']['name'] == 'example'
    return evaluate if @data['command']['name'] == 'eval'
    return <<~HELP
      Flags
        --help:   output this message

      Commands:
        example:  command to return a example file
        evaluate: load the argument file content and evaluate string in the 'eval' key

    HELP
  end

  ## template api

  def data
    @data
  end

  private

  def merge(original, override)
    original.merge(override) do |_key, original_value, value|
      value.is_a?(Hash) ? original_value.merge(value) : value
    end
  end

  def example
    File.read(__FILE__).split(/^__END__$/, 2).last
  end

  def evaluate
    eval(data['eval'])
  end
end

if caller.length == 0
  puts Yarb.new(ARGV).execute
end

__END__
---
# manual example
manual: |+
  # [ YARB! ](https://github.com/denislaliberte/yarb)

  ## how to

  Save the example file
  `$ yarb example > manual.yml`

  Evaluate the yaml file to output the manual
  `$ yarb evaluate manual.yml`

eval: return data['manual']
