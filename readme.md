# ActiveRecord Lite

### Background/Intro

This is a clone of some of the basic functionality offered by ActiveRecord. It was born out of an attempt to practice some metaprogramming techniques that I had just learned, and grew into something a little more serious.

### Usage

The basic usage can be obtained by opening a connection to a SQLite3 database. This will return an array of generated classes, on which you can both define relevant relations and run query methods. 
  
>```ruby
>require_relative 'base_connection'
>BaseConnection.connect('path_to_sqlite3.db')
>
>class User
>  has_many :questions
>end
>class Question
>  belongs_to :user
>end
>
>User.first.questions
>```

### Feature Set

This essentially uses the SQLite3 gem to establish a connection to the db, gather information about the tables present and their appurtenant columns. It uses this information to create a new model class for each table. On each of these classes, we gain access to a series of query methods. 

First of all, we gain access to a `find_by_?` method for every column name in the table. We also gain a general `where` method which can take a hash of options, as well as an `all` method.

We also define association methods on the generated classes. In this way, we can open up the class and use `has_many` and `belongs_to` options as one regularly might. Currently the `:through` option is in the works, along with `has_one`. We may expect the relevant methods to be created through the declaration of these associations (e.g., below, `users` would gain a `#questions` method).

The query methods actually return a BaseRelation object. This allows the query methods to be lazily loaded and stackable, as query methods are instance methods of BaseRelation objects. 

In attemptiong to implement query methods as stackable (which currently is non functional) it became obvious that what was necessary was a way of taking different bits of SQL and being able to compose it into a actual SELECT statement which would fetch relevant data. To this end I am implementing Sast (SQL AST), being inspired by ActiveRecord's Arel.

Sast is in essence a parser of SQL SELECT statements. It generates an abstract syntax tree of a given statement by performing lexical and syntactic analysis on a query string. It (will) also able to take two ASTs and compose them into a single one. It (will) also have a `#to_sql` method which returns the AST as a SQL compliant query string.

