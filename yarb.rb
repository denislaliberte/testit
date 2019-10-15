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
        ~/yarb.rb [arguments] [options]

      Options:

        --help           output this message
        --man            complete manual
        --example        list key of available example
        --example [key]  optput example file
        --on [env]       key of the config files environement
        --dry-run        dry run the commands
        -v, --verbose    verbose output
        --key [opts]     options to be used by the `opts(:key)` method

      Arguments:

        The first arguement is the path to a yrb file containing the variables

        The yrb file can declare more arguments that would be available with `args(1)` method

      Synopsis

        ~/yarb.rb variables.yrb test --dry-run --on prod
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
      wget ~ https://raw.githubusercontent.com/denislaliberte/yarb/master/yarb.rb
      chmod -x ~/yarb.rb
      ~/yarb.rb --help
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
    # save this file to $HOME/.yrb/config.yml
    # for `--on prod` use $HOME/.yrb/prod.yml
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
      operationName: <%= opts(:action, 'create') %>
      query: <%= files('query_file') %>
      schemaHandle: <%= opts(:schmea, 'merchant') %>
      versionHandle: <%= opts(:schmea, 'unstable') %>
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
    @alias = {
      '-h' => '--help',
      '-d' => '--dry-run'
    }
    @arguments = arguments.map {|argument| @alias[argument].nil? ? argument : @alias[argument] }
    @home = home
  end

  def execute
    load_files
    if path.nil? || flag?(:help)
      help
    elsif flag?(:man)
      manual
    else
      if flag?(:dry_run)
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
    return if args(0).nil? || !args(0).match(/\.yrb$/)
    args(0)
  end

  def args(index, default: nil)
    argument = @arguments.reject { |arg| arg.match(/^-/)}.at(index)
    return default if argument.nil?
    argument
  end

  def opts(key, default: nil)
    return default unless include?(key)
    value = argument_value(key)

    if value.nil?
      default
    else
      value
    end
  end

  def flag?(key)
    include?(key)
  end

  def string_key(symbol)
    "--#{symbol.to_s.gsub('_','-')}"
  end

  def config
    default = "#{@home}/.yrb/config.yml"
    if include?(:on)
      path = "#{@home}/.yrb/#{argument_value(:on)}.yml"
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

  def load_files
    Dir["#{@home}/.yrb/lib/*.rb"].each { |file| require file }
  end

  def include?(key)
    @arguments.include?(string_key(key))
  end

  def argument_value(key)
    index = string_key(key)
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
