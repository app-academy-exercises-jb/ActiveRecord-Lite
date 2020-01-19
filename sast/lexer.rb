module Lexer
  QUERIES = %w(select from join where limit)
  MODIFIERS = %w(distinct and as or)
  OPERATORS = %w(on between like in)

  def self.tokenize(query)
    tokens = []

    current_token = ""
    current_token_type = :word

    change_token = -> (token, type) { 
      if QUERIES.include?(token.downcase) 
        type = :reserved 
      elsif MODIFIERS.include?(token.downcase) 
        type = :modifier
      elsif OPERATORS.include?(token.downcase)
        type = :operator
      end
      tokens << Token.new(type, token) unless token == ""
      current_token = ""
    }

    inter_token = -> (token,type) {
      # periods and commas may sometimes be attached to a word
      change_token.call(current_token[0..-2], current_token_type)
      current_token_type = type
      change_token.call(token, current_token_type)
    }

    query.each_char.with_index { |chr,idx| 
      current_token += chr unless /\s/ === chr

      if /(\w|\.|\*)/ === chr
        # we are in the middle of(inclusive) a word
        current_token_type = :word
      elsif /'/ === chr
        # we're starting or stopping reading a value
        current_token_type = :value
      elsif /(>=|<=|<|>|=)/ === chr
        # we found an operator token
        current_token_type = :operator
      # elsif /\*/ === chr
      #   # we found a wildcard token
      #   # wildcard tokens are specific types of column names
      #   current_token_type = :wildcard
      elsif /,/ === chr
        # we found a comma token
        inter_token.call(",", :comma)
      # elsif /\./ === chr
      #   # we found a period token
      #   inter_token.call(".", :period)
      elsif /\(/ === chr || /\)/ === chr
        inter_token.call(chr, :paren)
      elsif /\)/ === chr
        # current_token_type = :paren
        # change_token.call(current_token,current_token_type)
      elsif /\s/ === chr
        # we finished reading a token
        change_token.call(current_token, current_token_type)
      else
        raise "fatal. unrecognized character #{chr}"
      end
    }

    change_token.call(current_token, current_token_type) unless current_token.empty?
    tokens
  end
end

class Token
  attr_reader :type, :value
  def initialize(type, value)
    @type, @value = type, value
  end
  def to_s
    value
  end
  def ==(val)
    value == val
  end
end

__END__
# test sql:
SELECT users.* FROM users WHERE lname = 'Miller'
SELECT users.* FROM users WHERE id = (SELECT id FROM users WHERE fname = 'Jorge')


"SELECT users.*,questions.* FROM users JOIN questions ON questions.author_id = users.id WHERE lname = 'Miller' AND fname IN (SELECT users.fname FROM users WHERE id > 3)"
# list of tokens we will find:
SELECT
FROM
JOIN
WHERE
AND
ON
names
=
(
)
*
'
,
.