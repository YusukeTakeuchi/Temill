# Temill

Temill shows objects to embedded comments in source code.

## Sample
```ruby
require 'temill'

Temill.show('Hello!, World!')

Temill.show <<-EOT
  You can use
  heredoc
EOT

5.times{| i |
  Temill.show(i ** 5)
}

Temill.show(
  %w(More complex arguments).map{| s |
    [s, s.upcase, s.downcase]
  }
)

Temill.emit
```
will output
```ruby
#--------------------------------
#/path/to/source.rb
#--------------------------------
require 'temill'

Temill.show('Hello!, World!')
# temill showing 1 results for line 3 (line 3 in this output)
# "Hello!, World!"

Temill.show <<-EOT
  You can use
  heredoc
EOT
# temill showing 1 results for line 5 (line 7 in this output)
# "  You can use\n  heredoc\n"

5.times{| i |
  Temill.show(i ** 5)
  # temill showing 5 results for line 11 (line 15 in this output)
  # 0
  # 1
  # 32
  # 243
  # 1024
}

Temill.show(
  %w(More complex arguments).map{| s |
    [s, s.upcase, s.downcase]
  }
)
# temill showing 1 results for line 14 (line 24 in this output)
# [["More", "MORE", "more"],
#  ["complex", "COMPLEX", "complex"],
#  ["arguments", "ARGUMENTS", "arguments"]]

Temill.emit
```


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'temill'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install temill


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/temill.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

