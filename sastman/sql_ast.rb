require_relative "lexer"
require_relative "parser"
require_relative 'sql_ast_node'


class SastMan
  module Traverser
    def traverse(root)
      puts root.to_sql
      root.options&.each { |(key, opt)|
        # p "key: " + key.to_s
        # p "opt: " + opt.to_s
        opt.is_a?(Array) ?
          opt.each { |o| traverse(o) } :
          traverse(opt)
      }
    end
  end
end

class SastMan
  extend Traverser
  extend Parser
  extend Lexer

  attr_reader :query
  
  def initialize(value=nil)
    @query = self.class.parse(value)
  end
  
  def compose(other_sast)
    other_query = other_sast.query

    case other_query.type
    when :select
    when :from
    when :joins 
    when :where
    else
    end
  end
  
  def compose!(other_sast)
    
  end

  def to_sql #here we will implement our Visitor
    @query.to_sql
  end
  
  private
  def self.parse(query)
    tokens = self.tokenize(query)
    ast = self.generate_tree(tokens)
  end
end
