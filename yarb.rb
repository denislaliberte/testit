#!/usr/bin/env ruby

require 'erb'
require 'yaml'

class Yarb
  def description
    "Use Yaml And RuBy to create simple command line tools quickly"
  end

  def usage
    <<~USAGE.chomp
      Usage:
        ~/yarb.rb [command] [arguments] [options]

      Commands:

        help             output this message
        man              complete manual

      Arguments:

        The first arguement is the path to a yml file containing the variables

        The yml file can declare more arguments that would be available with `args(1)` method

      Options:

        --example        list key of available example
        --example [key]  optput example file
        --dry-run        dry run the commands
        --verbose    verbose output
        --key [opts]     options to be used by the `opts(:key)` method

      Synopsis

        ~/yarb.rb variables.yml test --dry-run
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

  DEFAULT_CONFIG = {
    'default_command' => 'help',
    'alias' => {
      '-h' => '--help',
      '-d' => '--dry-run'
    }
  }


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
    @home = home
    @config = load_configuration
    @arguments = arguments
    override_alias
    load_files
  end

  @@command = {}

  def self.command(command, &block)
    @@command[command.to_s] = block
  end

  def execute
    if flag?(:dry_run)
      YAML.dump(data).to_s
    elsif command?(args(0))
      execute_command(args(0))
    else
      @arguments.unshift(@config['default_command'])
      execute
    end
  end

  command(:eval) { |yarb| yarb.evaluate }

  def evaluate
    eval(data['eval'])
  end

  def path
    return if args(1).nil? || !args(1).match(/\.yml$/)
    args(1)
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
    @config
  end

  def yaml_data
    yaml_template = File.read(path)
    yaml = ERB.new(yaml_template).result(binding)
    YAML.load(yaml)
  end

  def data
    override(@config, yaml_data)
  end

  def override(original, override)
    original.merge(override) do |_key, original_value, value|
      value.is_a?(Hash) ? original_value.merge(value) : value
    end
  end

  def verbose
    flag?(:verbose)
  end

  def help
    template = <<~HELP.chomp
      <%= description %>

      <%= usage %>
    HELP
    ERB.new(template).result(binding)
  end

  def workspace
    "#{@home}/.yrb"
  end

  private

  def load_configuration
    default_path = "#{workspace}/config.yml"
    if File.file?(default_path)
      override(DEFAULT_CONFIG, YAML.load_file(default_path))
    else
      DEFAULT_CONFIG
    end
  end

  command(:man) { |yarb| yarb.manual }
  command(:help) { |yarb| yarb.help }

  def command?(command)
    !@@command[command].nil?
  end

  def execute_command(command)
    return unless command?(command)
    @@command[command].call(self)
  end

  def override_alias
    @arguments = @arguments.map {|argument| @config['alias'][argument].nil? ? argument : @config['alias'][argument] }
  end

  def load_files
    Dir["#{workspace}/lib/*.rb"].each { |file| require file }
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

