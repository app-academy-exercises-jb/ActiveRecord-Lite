require_relative "lexer"
require_relative "parser"
require_relative 'sql_ast_node'

class Sast
  attr_reader :query
  
  def initialize(value=nil)
    @query = parse(value)
  end
  
  def compose(other_sast)
    #etc
  end
  
  def compose!(other_sast)
    
  end

  def to_sql #here we will implement our Visitor
    debugger
    ""
  end
  
  private
  def parse(query)
    tokens = Lexer.tokenize(query)
    ast = Parser.generate_tree(tokens)
  end
end