#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'erb'
require 'forwardable'

module Yarb
  class Yarb
    extend Forwardable
    attr_reader :data, :workspace

    def_delegators :@logger, :log

    def initialize(arguments, workspace: nil)
      @workspace = workspace
      @data = Hash.new { |h, k| h[k] = {} }
      @raw_arguments = arguments
      @logger = Logger.new
    end

    DEFAULT_CONFIG = {
      'log-level' => 'info',
      'log-console' => true,
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
      arguments = Hook.execute(:pre_configure, arguments: @raw_arguments, yarb: self).fetch(:arguments)
      @data = add_command_data(arguments, config)
      @logger.level = opts('log-level')
      @logger.console = opts('log-console')
      @data = get_file_data(@data)
      @data = Hook.execute(:post_configure, data: @data, yarb: self).fetch(:data)
      self
    end

    def get_config(default)
      return default unless File.file?("#{@workspace}/config.yml")

      file_data = YAML.load_file("#{@workspace}/config.yml")
      default.recursive_merge(file_data)
    end

    def execute
      return opts(:usage, default: 'There is no help defined') if flag?(:help)
      return source if flag?(:source)
      return example if flag?(:example)
      return data if flag?(:noop)

      return log(:warning, 'eval key is missing') if @data['eval'].nil?

      log(:debug, 'execute', data: @data)

      eval(@data['eval'])
    end

    def opts(key, default: nil)
      value = data[key.to_s]
      value.nil? ? default : value
    end

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
    end

    def filter_flag(raw_arguments)
      first_flag_index = raw_arguments.index { |arg| /^--/.match(arg) }
      first_flag_index.nil? ? raw_arguments : raw_arguments.take(first_flag_index)
    end

    def get_options(arguments)
      arguments
        .select { |key| key.match(/^--/) } # the key of the option is prefix with two dash : --key
        .map { |key| [key.sub('--', ''), arguments[arguments.index(key) + 1]] } # the value follow the key : --key value
        .map { |key, value| flag_value(key, value) }
        .to_h
    end

    def flag_value(key, value)
      # if there is no value the key is a flag : --flag --other-option value
      if value.nil? || value.match(/^--/)
        # if the key start with --no- the flag is negative : --no-key
        new_key = key.sub('no-', '')
        [new_key, new_key == key]
      else
        [key, value]
      end
    end

    def get_file_data(data)
      return data unless @data['file'] && File.file?(@data['file'])

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
  end

  class Hook
    @hooks = Hash.new { |value, key| value[key] = [] }

    def self.execute(name, **kwargs)
      return kwargs if @hooks[name].nil?

      @hooks[name].inject(kwargs) { |result, hook| hook.call(result) }
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
    attr_writer :console

    def initialize(level: :warning, console: true)
      raise ArgumentError, "#{level} is not a valid log level" unless LOG_LEVEL.keys.include?(level.to_sym)

      @level = level.to_sym
      @console = console
    end

    def level=(level)
      @level = level.to_sym
      log('debug', "LogLevel changed to #{@level}")
    end

    def log(level, message, **data)
      time = Time.now
      data = Hook.execute(:log, level: level, time: time, message: message, data: data)
      return unless @console && LOG_LEVEL[level.to_sym] <= LOG_LEVEL[@level]

      if data[:data].empty?
        puts "#{time} #{level}: #{message}"
      else
        puts data.to_yaml
      end
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
  <% if opts(:version) %>version: <%= opts(:version) %><% end %>

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
