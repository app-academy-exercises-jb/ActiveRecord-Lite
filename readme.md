# ActiveRecord Lite

## Background/Intro

This is a clone of some of the basic functionality offered by ActiveRecord. It was born out of an attempt to practice some metaprogramming techniques that I had just learned, and grew into something a little more serious. Essentially, it uses the SQLite3 gem to establish a connection to the db and gather information about the tables present and their appurtenant columns. It then uses this information to create a new `class` for each table, on each of which we gain access to a series of query methods.

## Usage

The basic usage can be obtained by opening a connection to a SQLite3 database. This will return an array of generated classes, on which you can both define relevant relations and run query methods. 
  
>```ruby
> require_relative 'base_connection'
> BaseConnection.connect('questions.db')
> 
> class User
>   has_many :questions,
>     foreign_key: :author_id
> end
> class Question
>   belongs_to :author,
>     class_name: "User"
> end
>```

## Feature Set

### Query Methods

First of all, we gain access to a `find_by_?` method for every column name in the table. We also gain two general query methods: `where` and `find_by`, both of which take a hash of options or a string. `where` is a lazy loader which returns a `BaseRelation` instance, whereas `find_by` is an eager loader: it returns the first record found, or nil. There are several other query methods, including: `all`, <s>`joins`</s>, `select`, and `limit`. `BaseRelation`s represent a temporary collection of values which we will return values as soon as we need them, which we can run query methods on.

These query methods can be stacked in whatever order the user likes, like this:

>```ruby
>User.where(subscribed: true).select(:fname).limit(10)
>```

This would turn into the following SQL statement: 
>```sql
>SELECT fname FROM users WHERE subscribed = 'true' LIMIT 10
>```

### Associations

We also define association methods on the generated classes. In this way, we can open up the class and use `has_many` and `belongs_to` options as one would do in ActiveRecord. Currently the `:through` option is in the works, along with `has_one`. We may expect the relevant methods to be created through the declaration of these associations. Following the code above, we can expect the following to work, respectively fetching the first user's questions, and the first question's user:

>```ruby
>User.first.questions
>Question.first.author
>```

### SastMan

As I was implementing the chainability/stackability of methods, it became obvious that what was necessary was a way of taking different bits of SQL and being able to compose it into an actual `SELECT` statement which would fetch relevant data. To this end I implemented `SastMan` (SQL AST Manager), being inspired by ActiveRecord's `Arel`.

`SastMan` is in essence a parser of a subset of SQL `SELECT` statements (check `parser.rb` for more documentation). It generates an abstract syntax tree of a given statement by performing lexical and syntactic analysis on a query string. It is also able to take two ASTs and compose them into a single one. `SastMan` objects also have a `#to_sql` method which returns the AST as a SQL compliant query string.

