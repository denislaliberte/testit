# [ YARB! ](https://github.com/denislaliberte/yarb)
version: 0.3.0

Use Yaml And RuBy to create simple command line tools quickly


## installation

YARB is a stand alone script using only the ruby standard librairy, install it with wget

```
wget ~ https://raw.githubusercontent.com/denislaliberte/yarb/master/yarb.rb
chmod -x ~/yarb.rb
~/yarb.rb --help
```


## usage
```

      Synopsis
        ~/yarb.rb file.yml [options]
        ~/yarb.rb --example

      Flags
        --help         Output this message or the usage of the file if provided
        --example      Output the example

      Options
        --log-level    set the level of the log to output
                        values: debug, info, warning, error, fatal, off
    
```

## how to

Save the example file
`$ yarb --example > manual.yml`

Evaluate the yaml file to output the manual
`$ yarb manual.yml`


## License
[MIT](https://choosealicense.com/licenses/mit/)

