#!/usr/bin/env ruby

require 'erb'
require 'net/http'
require 'uri'
require 'json'
require 'YAML'
puts "to use the --console install pry `$ gem install pry`" if ARGV.include?('--console')
require 'pry' if ARGV.include?('--console')

description = "Test it is a tool to test api on multiple environnements."

usage = <<~USAGE.chomp
Usage:
  ~/testit.rb [options] variable

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
# [ Test it ](https://github.com/denislaliberte/testit)

<%= description %>

## usage

```
<%= usage %>
```

## Installation

testit is a stand alone script using only the ruby standard librairy, install it with wget

```
wget ~ https://raw.githubusercontent.com/denislaliberte/testit/master/testit.rb
chmod -x ~/testit.rb
~/testit.rb --help
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
# save this file to $HOME/.testit.default.yml
# for `--on prod` use $HOME/.testit.prod.yml
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

verbose = !(ARGV & ['--verbose', '-v']).empty?
dryrun = !(ARGV & ['--dry-run', '-d']).empty?

def path
  ARGV.last
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

def args(index, default)
  if ARGV.include?('--args')
    position = ARGV.index('--args') + 1
    ARGV[position].split(',')[index]
  else
    default
  end
end

def default
  if ARGV.include?('--on')
    index = ARGV.index('--on') + 1
    env = ARGV[index]
    YAML.load_file("#{ENV['HOME']}/.testit.#{env}.yml")
    # TODO validate that the file exist and list the possible files
  else
    YAML.load_file("#{ENV['HOME']}/.testit.default.yml")
  end
end

def yaml_data
  yaml_template = File.read(path)
  yaml = ERB.new(yaml_template).result(binding)
  YAML.load(yaml)
end

if ARGV.include?('--help')
  puts description
  puts ""
  puts usage
elsif ARGV.include?('--man')
  puts ERB.new(manual).result(binding)
elsif ARGV.include?('--example')
  if ARGV[1].nil?
    example.each { |key, _| puts "testit.rb example #{key}"  }
  elsif example[ARGV[1].to_sym].nil?
    puts "This is not a valid example, try one of:"
    example.each { |key, _| puts "testit.rb example #{key}"  }
  else
    puts example[ARGV[1].to_sym]
  end
else
  if dryrun
    puts "dryrun"
    puts "File: #{path}" if verbose
    default_data = default
    p yaml_data
    p default_data
    data = default_data.merge(yaml_data) {|_key, default, value| value.is_a?(Hash) ? default.merge(value) : value }
    p data
  else
    puts "\nFile: #{path}" if verbose

    data = default.merge(yaml_data) {|_key, default, value| value.is_a?(Hash) ? default.merge(value) : value }

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

