# This parser is intended to work with a certain subset of SQLite SELECT statements. 
# This is that subset. <Bracketed expressions> are optional. Subqueries must be named with AS:
# SELECT
#   <DISTINCT>
#   table.column, ...,
# FROM
#   (table,subquery), ...,
#   <JOIN>
#     (table,subquery) ON expr(table.column = table.column)
#   <...>
# <WHERE>
#   expr(operators: <,<=,>,>=,!=,=,IN,BETWEEN,LIKE,AND; operands: table.column, subquery)
# <LIMIT>
#   value

# We observe the syntactic rules set out here: https://www.sqlite.org/lang_select.html

require "byebug"
module Parser
  def self.generate_tree(tokens)
    count = -1
    current_token = nil;

    return_options = ->(options,type,value) {
      options.empty? ?
        SastNode.new(type: type, value: value) :
        SastNode.new(type: type, value: value, options: options)
    }
    gather_values = ->(tokens, prc) {
      values = []
      current_val = [tokens[0]]
      tokens[1..-1].each { |token|
        prc.call(token) ?
          (values << current_val; current_val = [token]) :
          current_val << token
      }
      values << current_val
      values.map! { |val| self.generate_tree(val) }
    }
    counter = ->() { count += 1; current_token = tokens[count] }
    walk = ->() {
      counter.call
      options = Hash.new { |h,k| h[k.type] = k}

      case current_token.type
      when :reserved
        node_tokens = []
        type = current_token.value.downcase.to_sym
        
        counter.call
        until current_token == nil || (current_token.type == :reserved && current_token.value != "join")
          node_tokens << current_token
          counter.call
        end

        # we've detected a subquery
        if node_tokens[-1].value == "("
          until current_token.value == ")"
            node_tokens << current_token
            counter.call
          end
          node_tokens << current_token
          2.times { counter.call; node_tokens << current_token} #catch the name
        end
        
        # we've got a SELECT, which may have a DISTINCT, options, and several selected values
        if type == :select
          raise SyntaxError.new("expecting values for SELECT statement") if node_tokens.empty?

          value = node_tokens[0].value == "distinct" ?
            (options[:distinct] = true; self.generate_tree(node_tokens[1..-1])) :
            gather_values.call(node_tokens, ->(t) { t.type == :comma })

          until count >= tokens.length - 1
            count -= 1
            options[walk.call]
          end
        end
        
        # we've got a WHERE which has a series of operators and operands 
        if type == :where
          #value = gather_values.call(node_tokens, ->(t) { t.type == :modifier && t.value != "as" })
          # here we must implement an operator-precedence parser
          value = self.generate_tree(node_tokens)
        end

        # we've got a FROM, which may have multiple tables, subqueries, and JOINs
        if type == :from
          tables = []
          joins = []
          has_joins = false
          # separate our tables and joins
          node_tokens.each { |token|
            has_joins = true if !has_joins && token.value == "join"
            has_joins ? 
              joins << token :
              tables << token
          }

          if joins.any?
            options[:join] = gather_values.call(joins, ->(j) { j.type == :reserved })
          end

          raise SyntaxError.new("must select FROM a table or subquery") if tables.empty?
          
          value = gather_values.call(tables, ->(t) { t.type == :comma })
        end
        
        # we've found a JOIN, which may name a table or subquery and expects an operator ON
        if type == :join
          value = self.generate_tree(node_tokens)
        end

        # we've found a LIMIT
        if type == :limit
          value = self.generate_tree(node_tokens)
        end
        
        return_options.call(options,type,value)
      when :paren
        # we're in a subquery. collect the tokens till we find the closing paren, and call ::generate_tree on that
        subquery_tokens = [current_token]
        options = {}

        until current_token.type == :paren && current_token.value == ")"
          counter.call
          subquery_tokens << current_token
        end

        # the subquery may be named:
        if tokens[count+1]&.type == :modifier
          options = {alias: self.generate_tree([tokens[count+2]]) }
        end        

        value = self.generate_tree(subquery_tokens[1..-2])
        return_options.call(options,:query,value)
      when :word
        if tokens[count+1]&.type == :operator
          # we have to define a hierarchy for operator precedence
          name = self.generate_tree([tokens[count]])
          value = self.generate_tree(tokens[count+2..-1])
          
          SastNode.new(type: :operator, value: [name, value], options: {operator: tokens[count+1].value})
        else
          SastNode.new(type: :name, value: current_token.value)
        end
      when :value
        SastNode.new(type: :value, value: current_token.value)
      when :comma, :modifier
        self.generate_tree(tokens[1..-1])
      end
    }
    walk.call
  end
end