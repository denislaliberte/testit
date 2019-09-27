#!/usr/bin/env ruby

require 'erb'
require 'net/http'
require 'uri'
require 'json'
require 'YAML'
require 'securerandom'

puts "to use the --console install pry `$ gem install pry`" if ARGV.include?('--console')
require 'pry' if ARGV.include?('--console')

description = "Use Yaml And RuBy to create simple command line tools quickly"

usage = <<~USAGE.chomp
Usage:
  ~/ya.rb [options] variable

Options:

  --help           output this message
  --man            complete manual
  --example        list key of available example
  --example [key]  optput example file
  --on [env]       key of the config files environement
  --dry-run        dry run the commands
  --args [args]    list of arguments as comma separated value
  -v, --verbose    verbose output
  --console        open a pry console with the result of the query

Arguments:

  variables
    path to a yaml file containing the variables

USAGE

manual = <<~MANUAL
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
# save this file to $HOME/.yarb.default.yml
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
  operationName: <%= args(1, 'create') %>
  query: <%= files('query_file') %>
  schemaHandle: <%= kwargs(:schmea, 'merchant') %>
  versionHandle: <%= kwargs(:schmea, 'unstable') %>
  variables:
    id: "gid://shopify/DiscountCodeNode/1",
    discount:
      title: asdf
      startsAt: "2021-05-06T13:20:03Z",
      endsAt: "2022-05-06T13:20:03Z",
EXAMPLE

class TestIt
  def initialize(arguments, home)
    @arguments = arguments
    @home = home
  end

  def path
    @arguments.select {|arg| arg.match(/\.yml$/) }.last
  end

  def args(index, default: nil)
    # TODO: this is hard to use and can be way more flexible
    # key: support key value in command line args key:value
    # default: if not provided default to the key
    # values: a list of the possible value, if none are provided there is no validation
    # index: position of the argument in --args (optionnal), if none is provided use the count of the argument in the file
    # type: enforce type
    # ex.
    # <%= args(:id, default: 1, type: Int, position: 0) %>
    # <%= args(:operation, default: create, values: [:create, :update] ) %>
    # <%= args(:discountWithCode)
    #
    # add --list-args command to parse the template and list all the argument and possible value
    # --args = id,operation,discountWithCode
    # id : type: Int, defaut: 1, position: 0
    # operation :  default: create, values: [ create, update], position: 1
    # discountWithCode : defautl: discountWithCode, position: 2
    if include?('--args')
      result = argument_value('--args').split(',')[index]
      result.nil? ? default : result
    else
      default
    end
  end

  def config
    default = "#{@home}/.yarb.default.yml"
    if include?('--on')
      path = "#{@home}/.yarb.#{argument_value('--on')}.yml"
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

  private

  def include?(arg)
    @arguments.include?(arg)
  end

  def argument_value(arg)
    position = @arguments.index(arg) + 1
    @arguments[position]
  end
end

def default
  # TODO remove once the template is compile from the TestIt 
  TestIt.new(ARGV, ENV['HOME']).config
end

def args(index, default)
  # TODO remove once the template is compile from the TestIt 
  TestIt.new(ARGV, ENV['HOME']).args(index, default)
end

def uuid
  SecureRandom.uuid
end

def console(path, yaml_data, request, response, yaml, uri)
  _p = path
  _yd = yaml_data
  _rq = request
  _r = response
  _y = yaml
  _u = uri
  binding.pry
end

def yaml_data
  TestIt.new(ARGV, ENV['HOME']).yaml_data
end

verbose = !(ARGV & ['--verbose', '-v']).empty?
dryrun = !(ARGV & ['--dry-run', '-d']).empty?

if ! ARGV.select {|arg| arg.match(/\.yml$/) }.empty?
  test_it = TestIt.new(ARGV, ENV['HOME'])
  path = test_it.path
  puts "File: #{path}" if verbose
  data = test_it.data
  if dryrun
    puts "dryrun"
    default_data = default
    p yaml_data
    p default_data
    p data
  else
    uri = URI.parse(data['url'])
    puts "\nuri: #{uri}" if verbose
    request = Net::HTTP::Post.new(uri)

    puts "\nAuthentification" if verbose
    puts "key: #{data['key']}" if verbose
    puts "secret: #{data['secret']}" if verbose
    request.basic_auth(data['key'], data['secret']) # todo validate presence

    request.content_type = "application/json"
    request.body = JSON.dump(data['payload']) # TODO rename to body, validate presence
    puts "\nbody: #{request.body}" if verbose

    unless data['headers'].nil?
      data['headers'].each do |key, value|
        request[key] = value
      end
    end

    req_options = { use_ssl: uri.scheme == "https" }

    puts "\nyaml_data: #{YAML.dump(yaml_data)}" if verbose

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    puts "\nResponse" if verbose
    puts "\ncode: #{response.code}" if  response.code.to_i > 299 || verbose
    puts "\nbody: #{response.body}" if verbose

    json = JSON.load(response.body)
    yaml = YAML.dump(json)

    console(path, data, request, response, yaml, uri) if  ARGV.include?('--console')

    puts "\nResult" if verbose
    puts yaml
  end
end

if ARGV.include?('--help')
  puts description
  puts ""
  puts usage
elsif ARGV.include?('--man')
  puts ERB.new(manual).result(binding)
elsif ARGV.include?('--example')
  if ARGV[1].nil?
    example.each { |key, _| puts "yarb.rb example #{key}"  }
  elsif example[ARGV[1].to_sym].nil?
    puts "This is not a valid example, try one of:"
    example.each { |key, _| puts "yarb.rb example #{key}"  }
  else
    puts example[ARGV[1].to_sym]
  end
end
