# SyntaxSearch

Imagine you're programming, everything is awesome. You write code, it runs. Still awesome. You write more code, you save it, you run it and then:

```
file.rb:333: syntax error, unexpected `end', expecting end-of-input
```

What happened? Likely you forgot a `def`, `do`, or maybe you deleted some code and missed an `end`. Either way it's an extremely unhelpful error and a very time consuming mistake to track down.

What if I told you, that there was a library that helped find your missing `def`s and missing `do`s. What if instead of searching through hundreds of lines of source for the cause of your syntax error, there was a way to highlight just code in the file that contained syntax errors.

```
$ syntax_search path/to/file.rb

SyntaxErrorSearch: A syntax error was detected

This code has an unmatched `end` this is caused by either
missing a syntax keyword (`def`,  `do`, etc.) or inclusion
of an extra `end` line

file: path/to/file.rb
simplified:

  ```
       1  require 'animals'
       2
    ❯ 10  defdog
    ❯ 15  end
    ❯ 16
      20  def cat
      22  end
  ```
```

How much would you pay for such a library? A million, a billion, a trillion? Well friends, today is your lucky day because you can use this library today for free!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'syntax_search', require: "syntax_search/auto"
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install syntax_search

## What does it do?

When your code triggers a SyntaxError due to an "unexpected `end'" in a file, this library fires to narrow down your search to the most likely offending locations.

## Sounds cool, but why isn't this baked into Ruby directly?

I would love to get something like this directly in Ruby, but I first need to prove it's useful. The `did_you_mean` functionality started as a gem that was eventually adopted by a bunch of people and then Ruby core liked it enough that they included it in the source. The goal of this gem is to:

1. Get real world useage and feedback. If we gave you an awful suggestion, let us know! We try to handle lots of cases well, but maybe we could be better.
2. Prove out demand. If you like this idea, then vote for it by putting it in your Gemfile.

## How does it detect syntax error locations?

We know that source code that does not contain a syntax error can be parsed. We also know that code with a syntax error contains both valid code and invalid code. If you remove the invalid code, then we can programatically determine that the code we removed contained a syntax error. We can do this detection by generating small code blocks and searching for which blocks need to be removed to generate valid source code.

Since there can be multiple syntax errors in a document it's not good enough to check individual code blocks, we've got to check multiple at the same time. We will keep creating and adding new blocks to our search until we detect that our "frontier" (which contains all of our blocks) contains the syntax error. After this, we can stop our search and instead focus on filtering to find the smallest subset of blocks that contain the syntax error.

## How is source code broken up into smaller blocks?

By definition source code with a syntax error in it cannot be parsed, so we have to guess how to chunk up the file into smaller pieces. Once we've split up the file we can safely rule out or zoom into a specific piece of code to determine the location of the syntax error. This libary uses indentation and empty lines to make guesses about what might be a "block" of code. Once we've got a chunk of code, we can test it.

At the end of the day we can't say where the syntax error is FOR SURE, but we can get pretty close. It sounds simple when spelled out like this, but it's a very complicated problem. Even when code is not correctly indented/formatted we can still likely tell you where to start searching even if we can't point at the exact problem line or location.

## How does this gem know when a syntax error occured in my code?

Right now the search isn't performed automatically when you get a syntax error. Instead we append a warning message letting you know how to test the file. Eventually we'll enable the seach by default instead of printing a warning message. To do both of these we have to monkeypatch `require` in the same way that bootsnap does.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/zombocom/syntax_search. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/syntax_search/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SyntaxErrorSearch project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/zombocom/syntax_search/blob/master/CODE_OF_CONDUCT.md).
