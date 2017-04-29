# Bankscrap::Openbank

[Bankscrap](https://github.com/bankscrap/bankscrap) adapter for Openbank.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bankscrap-openbank'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install bankscrap-openbank

## Usage

### From terminal
#### Bank account balance

    $ bankscrap balance Openbank --credentials=user:YOUR_USER --password:YOUR_PASSWORD


#### Transactions

    $ bankscrap transactions Openbank --credentials=user:YOUR_USER --password:YOUR_PASSWORD

---

For more details on usage instructions please read [Bankscrap readme](https://github.com/bankscrap/bankscrap/#usage).

### From Ruby code

```ruby
require 'bankscrap-openbank'
openbank = Bankscrap::Openbank::Bank.new(user: YOUR_USER, password: YOUR_PASSWORD)
```


## Contributing

1. Fork it ( https://github.com/bankscrap/bankscrap-openbank/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
