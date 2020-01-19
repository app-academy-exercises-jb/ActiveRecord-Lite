require_relative "lexer"
require_relative "parser"

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

  def to_sql
    # here we'll want to travese our nodes in order, to_s'ing along the way
    debugger
    ""
  end
  
  private
  def parse(query)
    tokens = Lexer.tokenize(query)
    ast = Parser.generate_tree(tokens)
  end
end


class SastNode
  attr_reader :type, :value, :options
  # attr_accessor :next, :prev

  def initialize(type:, value: nil, child: nil, options:{})
    @type = type
    @value = value
    @options = options unless options.empty?
  end

  def to_s
    if type == :operator
      "#{@value[0]} #{options[:operator]} #{@value[1].to_s}"
    else
      @options.nil? ?
        "{:#{@type}=>#{@value}}" :
        "{:#{@type}=>#{@value},\n#{options.values.join(",\n")}}"
    end
  end

  def inspect
    if type == :operator
      "#{@value[0]} #{options[:operator]} #{@value[1].to_s}"
    elsif type == :query
      "{:#{@type}=>#{@value},\n#{options.values.join(",\n")}}"
    else
      @options.nil? ? 
        {@type => @value} :
        [{@type => @value}, *options.values].join(",\n")
    end
  end
end
