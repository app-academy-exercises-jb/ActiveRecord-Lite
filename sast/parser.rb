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
class Sast
  module Parser
    PRECEDENCE = {
      nil => -1, 
      "on" => 0,
      "or" => 0,
      "and" => 1,
      "like" => 2,
      "in" => 2,
      "!=" => 2,
      "=" => 2,
      ">=" => 3,
      ">" => 3,
      "<=" => 3,
      "<" => 3,
      "-" => 4,
      "+" => 4,
      "/" => 5,
      "*" => 5
    }
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

      comp_ops = ->(opers, opans, tok) {
        if PRECEDENCE[tok.value] > PRECEDENCE[opers[-1].value]
          opers << tok
        else
          # raise "fatal: binary operation with more than two operands" unless opans.length == 2
          new_operand = self.generate_tree([opers.pop, opans.pop, opans.pop])
          opans << new_operand
          opers << tok
        end
      }

      parse_operators = ->(tokens) {
        operators = [Lexer::NullToken]
        operands = []

        paren_count = 0
        subquery = []
        

        tokens.each { |tok| 
          if paren_count > 0
            subquery << tok
            if tok.value == ")"
              paren_count -= 1
              operands << self.generate_tree(subquery) if paren_count == 0
            elsif tok.value == "("
              paren_count += 1
            end
          else
            if tok.type == :operator
              comp_ops.call(operators, operands, tok)
            elsif tok.value == "("
              paren_count += 1
              subquery << tok
            else
              operands << tok
            end
          end
        }
        

        until operators.length == 2
          # operands << comp_ops.call(operators, operands, operators.pop)
          new_operand = self.generate_tree([operators.pop, operands.pop, operands.pop])
          operands << new_operand
        end

        self.generate_tree([operators.pop, operands.pop, operands.pop])

        # raise "fatal: did not resolve" unless operands.length == 1
        # operands[0]
      }

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
            # FROM + JOIN must name subqueries
            # WHERE need not
            2.times { counter.call; node_tokens << current_token} unless type == :where #catch the name
            raise SyntaxError.new("subquery must be named") if node_tokens[-1].nil?
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
        when :word, :value
          if tokens[count+1]&.type == :operator
            
            parse_operators.call(tokens)
          else
            type = current_token.type == :word ? :name : :value
            SastNode.new(type: type, value: current_token.value)
          end
        when :comma, :modifier
          self.generate_tree(tokens[1..-1])
        when :operator
          # we expect to have two tokens.
          # tokens[0], tokens[1]
          left = tokens[1].is_a?(SastNode) ? tokens[1] : self.generate_tree([tokens[1]])
          right = tokens[2].is_a?(SastNode) ? tokens[2] :  self.generate_tree([tokens[2]])
          SastNode.new(type: :operator, value: [right, left], options: {operator: current_token.value})
        end
      }
      
      walk.call
    end
  end
end