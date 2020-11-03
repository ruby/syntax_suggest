# SyntaxErrorSearch

Imagine you're programming, everything is awesome. You write code, it runs. Still awesome. You write more code, you save it, you run it and then:

```
file.rb:333: syntax error, unexpected `end', expecting end-of-input
```

What happened? Likely you forgot a `def`, `do`, or maybe you deleted some code and missed an `end`. Either way it's an extremely unhelpful error and a very time consuming mistake to track down.

What if I told you, that there was a library that helped find your missing `def`s and missing `do`s. What if instead of searching through hundreds of lines of source for the cause of your syntax error, there was a way to highlight just code in the file that contained syntax errors.

```
# TODO example here
```

How much would you pay for such a library? A million, a billion, a trillion? Well friends, today is your lucky day because you can use this library today for free!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'syntax_error_search'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install syntax_error_search

## What does it do?

When your code triggers a SyntaxError due to an "expecting end-of-input" in a file, this library fires to narrow down your search to the most likely offending locations.

## Sounds cool, but why isn't this baked into Ruby directly?

I would love to get something like this directly in Ruby, but I first need to prove it's useful. The `did_you_mean` functionality started as a gem that was eventually adopted by a bunch of people and then Ruby core liked it enough that they included it in the source. The goal of this gem is to:

1. Get real world useage and feedback. If we gave you an awful suggestion, let us know! We try to handle lots of cases well, but maybe we could be better.
2. Prove out demand. If you like this idea, then vote for it by putting it in your Gemfile.

## How does it detect syntax error locations?

Source code with a syntax error in it can be thought of valid code with one or more invalid chunks in it. With this in mind we can "search" for both invalid and valid chunks of code. This library uses a parser to tell if a given chunk of code is valid in which case it's certainly not the cause of our problem. If it's invalid, then we can test to see if removing that chunk from our file would make the whole thing valid. When that happens, we've narrowed down our search. But...things aren't always so easy.

By definition source code with a syntax error in it cannot be parsed, so we have to guess how to chunk up the file into smaller pieces. Once we've split up the file we can safely rule out or zoom into a specific piece of code to determine the location of the syntax error. This libary uses indentation and empty lines to make guesses about what might be a "block" of code. Once we've got a chunk of code, we can test it.

- If the code parses, it cannot be the cause of our syntax error. We can remove it from our search
- If the code does not parse, it may be the cause of the error, but we also might have made a bad guess in splitting up the source
  - If we remove that chunk of code from the document and that allows the whole thing to parse, it means the syntax error was for sure in that location.
  - Otherwise, it could mean that either there are multiple syntax errors or that we have a bad guess and need to expand our search.

At the end of the day we can't say where the syntax error is FOR SURE, but we can get pretty close. It sounds simple when spelled out like this, but it's a very complicated problem.

This one person on twitter told me it's "not possible".

## How does this gem know when a syntax error occured?

While I wish you hadn't asked: If you must know, we're monkey-patching require. It sounds scary, but bootsnap does essentially the same thing and we're way less invasive.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/syntax_error_search. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/syntax_error_search/blob/master/CODE_OF_CONDUCT.md).


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the SyntaxErrorSearch project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/syntax_error_search/blob/master/CODE_OF_CONDUCT.md).
