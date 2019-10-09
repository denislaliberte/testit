#!/usr/bin/env ruby

require 'erb'
require 'net/http'
require 'uri'
require 'json'
require 'yaml'
require 'securerandom'

class Yarb
  def description
    "Use Yaml And RuBy to create simple command line tools quickly"
  end

  def usage
    <<~USAGE.chomp
      Usage:
        ~/ya.rb [options] variable

      Options:

        --help           output this message
        --man            complete manual
        --example        list key of available example
        --example [key]  optput example file
        --on [env]       key of the config files environement
        --dry-run        dry run the commands
        --key [args]     args to be used by the args(:key) method
        -v, --verbose    verbose output

      Arguments:

        variables
          path to a yaml file containing the variables
    USAGE
  end

  def manual
    template = <<~MANUAL.chomp
      # [ YARB! ](https://github.com/denislaliberte/yarb)

      <%= description %>

      ## usage

      ```
      <%= usage %>
      ```

      ## Installation

      YARB is a stand alone script using only the ruby standard librairy, install it with wget

      ```
      wget ~ https://raw.githubusercontent.com/denislaliberte/yarb/master/ya.rb
      chmod -x ~/ya.rb
      ~/ya.rb --help
      ```

      ## examples file

      ### simple example
      ```
      <%= example[:simple] %>
      ```

      ### config example

      You can add a config file to your home directory, the value of this file will be used
      as default on all of your query
      ```
      <%= example[:config] %>
      ```

      ## License
      [MIT](https://choosealicense.com/licenses/mit/)
    MANUAL

    return ERB.new(template).result(binding)
  end

  def example
    example = {}

    example[:simple] = <<~EXAMPLE
    ---
    url: "https://api.example.com/surprise"
    key: banana
    secret: coconuts
    payload:
      appID: placeholder
      userID: placeholder
      variables:
        first: 10
      query: >-
        query PriceRules($first: Int) {
          priceRules(first: $first) {
            edges{
              node{
                id
              }
            }
          }
        }
    EXAMPLE

    example[:config] = <<~EXAMPLE
    ---
    # save this file to $HOME/.yarb.yml
    # for `--on prod` use $HOME/.yarb.prod.yml
    url: "https://api.example.com/surprise"
    key: banana
    secret: coconuts
    payload:
      appID: placeholder
      userID: placeholder
    EXAMPLE

    example[:complex] = <<~EXAMPLE
    testit_with:
      query_file:

    payload:
      operationName: <%= args(:action, 'create') %>
      query: <%= files('query_file') %>
      schemaHandle: <%= args(:schmea, 'merchant') %>
      versionHandle: <%= args(:schmea, 'unstable') %>
      variables:
        id: "gid://shopify/DiscountCodeNode/1",
        discount:
          title: asdf
          startsAt: "2021-05-06T13:20:03Z",
          endsAt: "2022-05-06T13:20:03Z",
    EXAMPLE
    return example
  end

  def initialize(arguments, home)
    @arguments = arguments
    @home = home
  end

  def execute
    if path.nil? || flag?(:help, :h)
      help
    elsif flag?(:man)
      manual
    else
      if flag?(:dry_run, :d)
        YAML.dump(data).to_s
      elsif(data['eval'].kind_of?(Array))
        data['eval'].each do |key|
          eval(data[key]['eval'])
        end
      else
        eval(data['eval'])
      end
    end
  end

  def path
    @arguments.select {|arg| arg.match(/\.yml$/) }.last
  end

  def args(key, short_key = nil, default: nil)
    return default unless include?(key, short_key)
    value = argument_value(key, short_key)

    if value.nil?
      default
    else
      value
    end
  end

  def flag?(key, short_key=nil)
    include?(key, short_key)
  end

  def string_key(symbol, prefix = '--')
    "#{prefix}#{symbol.to_s.gsub('_','-')}"
  end

  def config
    default = "#{@home}/.yarb.yml"
    if include?(:on, :o)
      path = "#{@home}/.yarb.#{argument_value(:on, :o)}.yml"
      raise "The file #{path} don't exist" unless File.file?(path)
      YAML.load_file(path)
    elsif File.file?(default)
      YAML.load_file(default)
    else
      {}
    end
  end

  def yaml_data
    yaml_template = File.read(path)
    yaml = ERB.new(yaml_template).result(binding)
    YAML.load(yaml)
  end

  def data
    config.merge(yaml_data) {|_key, config_default, value| value.is_a?(Hash) ? config_default.merge(value) : value }
  end

  def verbose
    false
  end

  def help
    template = <<~HELP.chomp
      <%= description %>

      <%= usage %>
    HELP
    ERB.new(template).result(binding)
  end

  private

  def include?(key, short_key = nil)
    @arguments.include?(string_key(key)) || (!short_key.nil? && @arguments.include?(string_key(short_key, '-')))
  end

  def argument_value(key, short_key)
    index = include?(key) ? string_key(key) : string_key(short_key, '-')
    return nil if @arguments.index(index).nil?
    position = @arguments.index(index) + 1
    return nil if /^-/.match(@arguments[position])
    @arguments[position]
  end
end

if caller.length == 0
  puts Yarb.new(ARGV, ENV['HOME']).execute
end

#if ARGV.include?('--example')
#  if ARGV[1].nil?
#    example.each { |key, _| puts "yarb.rb example #{key}"  }
#  elsif example[ARGV[1].to_sym].nil?
#    puts "This is not a valid example, try one of:"
#    example.each { |key, _| puts "yarb.rb example #{key}"  }
#  else
#    puts example[ARGV[1].to_sym]
#  end
#end
