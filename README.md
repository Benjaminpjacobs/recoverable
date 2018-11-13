[![Version      ](https://img.shields.io/gem/v/recoverable.svg?maxAge=2592000)](https://rubygems.org/gems/recoverable)
[![Build Status ](https://travis-ci.com/Benjaminpjacobs/ship_station.svg)](https://travis-ci.com/Benjaminpjacobs/recoverable)
[![Maintainability](https://api.codeclimate.com/v1/badges/dd436c45c8a52dc8c13c/maintainability)](https://codeclimate.com/github/Benjaminpjacobs/recoverable/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/dd436c45c8a52dc8c13c/test_coverage)](https://codeclimate.com/github/Benjaminpjacobs/recoverable/test_coverage)

## Recoverable

Recoverable is a simple DSL that works at the class level to configure retries of instance methods. With a multitude of customizations this gem can combined with ruby's class inheritence can be a powerful tool for drying up code.

## Installation

Install the gem: 

```sh
$ gem install 'recoverable'
```

Add it to your gemfile:

```ruby
gem 'recoverable'
```

Then run bundle to install the Gem:

```sh
$ bundle install
```

## Usage

Recoverable gives you a dynamic way to retry and handle errors on an instance of a class or an inherited class.

### Default Behavior

You can add recoverable to your class by simply extending the Gem and then telling it which method you would like to recover from and how many times you would like to retry.

```ruby
  class Foo
    extend Recoverable
    recover :bar, tries: 2

    def bar
      baz
    end

  end
```
With the above configuration any instance of `Foo` will recover any `StandardError` on `#bar` and retry 2 times without a sleep between retries. After the second retry it will raise the error `Recoverable::RetryCountExceeded` along with the information about what error had occured.

### Configuration Options

Recoverable allows for varied configurations to alter the behavior of the rescue and retry.

#### Errors

Setting up your class with the following will specifically recover on `CustomError`.

```ruby
  class Foo
    extend Recoverable
    recover :bar, tries: 2, on: CustomError

    def bar
      baz
    end

  end
```
Note that this configuration will on rescue and retry on CustomError and will not rescue any other error including `StandardError`.

Recoverable can rescue on a collection of errors as well, however these must be passed to `on:` as an array.

```ruby
  recover :bar, tries: 2, on: [ CustomError, OtherCustomError ]
```
In the above case both `CustomError` and `OtherCustomError` will be rescued on the `#bar` method.

#### Sleep

Setting up your class with the following configuration will insert a 3 second sleep command between each retry:

```ruby
  class Foo
    extend Recoverable
    recover :bar, tries: 2, sleep: 3

    def bar
      baz
    end

  end
```

#### Custom Exception

In addition to retrying, recoverable allows you to throw a custom exception after the rescue and retry attempts.

```ruby

  class MyException < StandardError; end

  class Foo
    extend Recoverable
    recover :bar, tries: 2, throw: MyException

    def bar
      baz
    end

  end
```

In this configuration after bar was retried twice recoverable would not raise `StandardError` or `Recoverable::RetryCountExceeded` but would instead raise `MyException`

#### Custom Handler

Recoverable also allows you to configure a custom error handling method. This should be a method defined on the class or parent class of the instance.

```ruby
  class Foo
    extend Recoverable
    recover :bar, tries: 2, custom_handler: :handle_error

    def bar
      baz
    end

    def handle_error(:error)
      "#{error} was retried twice, raised and then this method was called."
    end
  end
```

Please note that the name of the handler method should be passed to the configuration as a symbol. Also, the handler method can take either no arguments or a single keyword argument for `error:` if you would like access to the error inside the handler. Any other data inside the handler should be retrieved via instance methods or instance variables.


### Inheritence

One of the more powerful aspects of the recoverable implementation is how it handles inheritence.

In the following example, recoverable is setup on the `#bar` method which is defined on both the parent and child class.

```ruby
  class ParentClass
    extend Recoverable
    recover :bar, tries: 2
    def bar
      baz
    end

  end

  class ChildClass < ParentClass
    def bar
      super
    end

    def baz; end
  end

```

Now any call to bar that results in an error registered with the recoverable gem will be rescued and retried based on the configuration as long as the error occurs in the parent scope.

However in the following case the recoverable gem will rescue the error at the child level even though the error occurs in the parent class:

```ruby
  class ParentClass
    def bar
      baz
    end

  end

  class ChildClass < ParentClass
    extend Recoverable
    recover :bar, tries: 2
    def bar
      super
    end

    def baz; end
  end

```

The gem will rescue down through multiple inheritence as well:

```ruby
  class ParentClass
    extend Recoverable
    recover :bar, tries: 2
    def bar
      baz
    end

  end

  class ChildClass < ParentClass
    def baz; end
  end

  class SubChildClass < ChildClass
    def bar
      super
    end
  end
```
In the above, a call to the subchild class will throw an error that will be caught and retried by the recoverable configuration in the top level parent class

Lastly, error handler methods can be defined on either the parent or child class. For example, assuming that the method `bar` is called from a `ChildClass` instance, in the first example below the `handle_error` method will be called from the `ParentClass`

```ruby
 class ParentClass
    extend Recoverable
    recover :bar, tries: 2, custom_handler: :handle_error

    def bar
      baz
    end

    def handle_error(error:)
      "Parent Handler!"
    end
  end

  class ChildClass < ParentClass
    def baz; end
  end
```
However, in the next example, the same configuration would call the `handle_error` method from the `ChildClass` instance

```ruby
class ParentClass
  extend Recoverable
  recover :bar, tries: 2, custom_handler: :handle_error

  def bar
    baz
  end

  def handle_error(error:)
    "Parent Handler!"
  end

end

class ChildClass < ParentClass
  def baz; end

  def handle_error(error:)
    "Child Handler!"
  end
end
```
## How to contribute

* Fork the project
* Create your feature or bug fix
* Add the requried tests for it.
* Commit (do not change version or history)
* Send a pull request against the *development* branch

## Copyright
Copyright (c) 2018 Ben Jacobs
Licenced under the MIT licence.

