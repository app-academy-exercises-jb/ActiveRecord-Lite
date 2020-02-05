# ActiveRecord Lite

## Background/Intro

This is a clone of some of the basic functionality offered by ActiveRecord. It was born out of an attempt to practice some metaprogramming techniques that I had just learned, and grew into something a little more serious. Essentially, it uses the SQLite3 gem to establish a connection to the db and gather information about the tables present and their appurtenant columns. It then uses this information to create a new `class` for each table, on each of which we gain access to a series of query methods. These methods make use of a homespun SQL AST manager (`SastMan`) which allows them to be chained arbitrarily.

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

First of all, every generated class gains access to a `find_by_?` method for every column name in the corresponding table. They also gain two general query methods: `where` and `find_by`, both of which take a hash of options or a string. `where` is a lazy loader which returns a `BaseRelation` instance, whereas `find_by` is an eager loader: it returns the first record found, or nil. There are several other query methods, including: `all`, <s>`joins`</s>, `select`, and `limit`. `BaseRelation` objects represent a query (stored as a `SastMan` instance), and will return the values of the query results as soon as we need them. `BaseRelation` objects also have access to the query methods. 

These methods can be chained in whatever order is preferred, like this:

>```ruby
>User.where(subscribed: true).select(:fname).limit(10)
>```

This would turn into the following SQL statement: 
>```sql
>SELECT fname FROM users WHERE subscribed = 'true' LIMIT 10
>```

### Associations

We also define association methods on the generated classes. In this way, we can open up the class and use `has_many` and `belongs_to` options as one would do in ActiveRecord. Currently the `:through` option is in the works, along with `has_one`. We may expect the relevant methods to be created through the declaration of these associations. Following with the code above, we can expect the following to work, respectively fetching the first user's questions, and the first question's author:

>```ruby
>User.first.questions
>Question.first.author
>```

### SastMan

As I was trying to implement query method chaining, it dawned on me that what I needed was a way of taking different bits of SQL and being able to compose it into an valid `SELECT` statement which would fetch the relevant data. To this end I implemented `SastMan` (SQL AST Manager), being inspired by ActiveRecord's `Arel`.

`SastMan` is in essence a parser of a subset of SQL `SELECT` statements (check `parser.rb` for the syntax which is covered). It generates an abstract syntax tree of a given statement by performing lexical and syntactic analysis on a query string. In particular, a lexer passes over a string literal, returning an array of tokens. The tokens are then passed to the parser, which generates the AST by using a technique known as recursive descent, specifically implementing Dijkstra's Shunting Yard Algorithm for parsing operator precedence. 

Given that we only parse one type of SQL statement, implementing recursive descent was fairly simple. Operator precedence only needs to be worked out within subexpressions, specifically the ones found inside the `WHERE` clause of the `SELECT` statement.

Finally, `SastMan` is able to take two ASTs and compose them into a single one: this is the core functionality which enables query method chaining. `SastMan` objects also have a `#to_sql` method which returns the AST as a SQL compliant query string.