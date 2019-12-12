#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'erb'
require 'forwardable'

module Yarb
  class Yarb
    extend Forwardable
    attr_reader :data

    def_delegators :@logger, :log

    def initialize(arguments, workspace: nil)
      @workspace = workspace
      @data = Hash.new { |h, k| h[k] = {} }
      @raw_arguments = arguments
      @logger = Logger.new
    end

    DEFAULT_CONFIG = {
      'log-level' => 'info',
      'usage' => %(
        Synopsis
          ~/yarb.rb file.yml [options]
          ~/yarb.rb --example

        Flags
          --help         Output this message or the usage of the file if provided
          --example      Output the example

        Options
          --log-level    set the level of the log to output
                          values: debug, info, warning, error, fatal, off
      )
    }.freeze

    def configure
      load_lib
      config = get_config(DEFAULT_CONFIG)
      arguments = Hook.execute(:pre_configure, @raw_arguments)
      @data = add_command_data(arguments, config)
      @logger.level = option('log-level')
      @data = get_file_data(@data)
      self
    end

    def get_config(default)
      return default unless File.file?("#{@workspace}/config.yml")

      file_data = YAML.load_file("#{@workspace}/config.yml")
      default.recursive_merge(file_data)
    end

    def execute
      return option(:usage, default: 'There is no help defined') if flag?(:help)
      return source if flag?(:source)
      return example if flag?(:example)
      return data if flag?(:noop)

      log(:debug, "execute #{@data.to_yaml}")

      evaluate
    end

    def option(key, default: nil)
      value = data[key.to_s]
      value.nil? ? default : value
    end
    alias opts option

    def flag?(key)
      data[key.to_s]
    end

    private

    def load_lib
      return if @workspace.nil?

      Dir["#{@workspace}/lib/*.rb"].each { |file| require file }
    end

    def add_command_data(raw_arguments, default)
      arguments = filter_flag(raw_arguments)
      default
        .recursive_merge('file' => arguments[0])
        .recursive_merge(get_options(raw_arguments))
        .recursive_merge(get_flags(raw_arguments))
    end

    def filter_flag(raw_arguments)
      first_flag_index = raw_arguments.index { |arg| /^--/.match(arg) }
      first_flag_index.nil? ? raw_arguments : raw_arguments.take(first_flag_index)
    end

    def get_options(arguments)
      arguments
        .select { |key| key.match(/^--/) } # an option key is prefix with two dash : --key
        .map { |key| [key.gsub('--', ''), arguments[arguments.index(key) + 1]] } # the value follow the key : --key value
        .select { |_key, value| !value.nil? && !value.match(/^--/) } # key not follow by a value is not a option
        .to_h
    end

    def get_flags(arguments)
      arguments
        .select { |key| key.match(/^--/) } # an option key is prefix with two dash : --key
        .map { |key| [key.gsub('--', ''), arguments[arguments.index(key) + 1]] } # the value follow the key : --key value
        .select { |_key, value| value.nil? || value.match(/^--/) } # key not follow by a value is not a option
        .map { |key, _value| [key, true] }
        .to_h
    end

    def get_file_data(data)
      return data unless @data['file']

      yaml = ERB.new(source).result(binding)
      argument_data = YAML.safe_load(yaml)
      data.recursive_merge(argument_data)
    end

    def source
      File.read(@data['file'])
    end

    def example
      File.read(__FILE__).split(/^__END__$/, 2).last
    end

    def evaluate
      return log(:warning, 'eval key is missing') if data['eval'].nil? || data['eval'].empty?

      eval(data['eval'])
    end
  end

  class Hook
    @hooks = Hash.new([])

    def self.execute(name, data)
      @hooks[name].inject(data) do |result, hook|
        hook.call(result)
      end
    end

    def self.register(name, &hook)
      @hooks[name] << hook
    end

    def self.clear(name)
      @hooks[name].clear
    end
  end

  class Logger
    LOG_LEVEL = { debug: 5, info: 4, warning: 3, error: 2, fatal: 1, off: 0 }.freeze

    def initialize(level: :warning)
      raise ArgumentError, "#{level} is not a valid log level" unless LOG_LEVEL.keys.include?(level.to_sym)

      @level = level.to_sym
    end

    def level=(level)
      @level = level.to_sym
      log('debug', "LogLevel changed to #{@level}")
    end

    def log(level, message)
      puts "#{level}: #{message}" if LOG_LEVEL[level.to_sym] <= LOG_LEVEL[@level]
    end
  end
end

class Hash
  def recursive_merge(override)
    merge(override) do |_key, original_value, value|
      value.is_a?(Hash) ? original_value.merge(value) : value
    end
  end
end

puts Yarb::Yarb.new(ARGV, workspace: "#{ENV['HOME']}/.yrb").configure.execute if caller.empty?

__END__
---
usage: |+
  Generate the yarb manual

  Synopsis:
    yarb manual.yml
    yarb manual.yml --version 1.0
    yarb manual.yml --install

manual: |+
  # [ YARB! ](https://github.com/denislaliberte/yarb)
  <% if option(:version) %>version: <%= option(:version) %><% end %>

  Use Yaml And RuBy to create simple command line tools quickly

  <% if flag?(:install) %>
  ## installation

  YARB is a stand alone script using only the ruby standard librairy, install it with wget

  ```
  wget ~ https://raw.githubusercontent.com/denislaliberte/yarb/master/yarb.rb
  chmod -x ~/yarb.rb
  ~/yarb.rb --help
  ```
  <% end %>

  ## usage
  ```
  <%= DEFAULT_CONFIG['usage'] %>
  ```

  ## how to

  Save the example file
  `$ yarb --example > manual.yml`

  Evaluate the yaml file to output the manual
  `$ yarb manual.yml`


  ## License
  [MIT](https://choosealicense.com/licenses/mit/)

eval: |+
  return data['manual']
