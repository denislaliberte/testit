# [ YARB! ](https://github.com/denislaliberte/yarb)

Use Yaml And RuBy to create simple command line tools quickly

## usage

```
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

Arguments:

  variables
    path to a yaml file containing the variables

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

```

### config example

You can add a config file to your home directory, the value of this file will be used
as default on all of your query
```
---
# save this file to $HOME/.yarb.default.yml
# for `--on prod` use $HOME/.yarb.prod.yml
url: "https://api.example.com/surprise"
key: banana
secret: coconuts
payload:
  appID: placeholder
  userID: placeholder

```

## License
[MIT](https://choosealicense.com/licenses/mit/)
