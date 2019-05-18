# Test it

Test it is a tool to test api on multiple environnements.

## usage

```
Usage:
  ~/testit.rb [options] variable

Options:

  --help           output this message
  --man            complete manual
  --example        list key of available example
  --example [key]  optput example file
  --on [env]       key of environement, see testit_on in example
  --dry-run        dry run the commands
  -v, --verbose    verbose output
  --console        open a pry console with the result of the query

Arguments:

  variables
    path to a yaml file containing the variables

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
# save this file to $HOME/.testit.yml
url: "https://api.example.com/surprise"
key: banana
secret: coconuts
payload:
  appID: placeholder
  userID: placeholder

```

## License
[MIT](https://choosealicense.com/licenses/mit/)
