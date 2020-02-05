class SastMan
  class SastNode
    attr_reader :options
    attr_accessor :value
    # attr_accessor :next, :prev
    # redefine self.new in order to return different types of nodes based on the options being passed in
    # types of nodes:
    ## operator
    ## const
    ## query
    def self.new(type:, value: nil, options:{})
      # debugger
      return super unless self == SastNode
      case type
      when :select, :where, :join, :from, :limit
        QueryNode.new(type: type, value: value, options: options)
      # when :from
      #   FromNode.new(type: type, value: value, options: options)
      when :name, :value
        ConstNode.new(type: type, value: value, options: options)
      when :operator
        OperNode.new(type: type, value: value, options: options)
      when :query
        SubQueryNode.new(type: type, value: value, options: options)
      else
        raise "unknown type: #{type}"
      end

    end

    def initialize(type:, value: nil, options: {})
      @type = type
      @value = value
      @options = options.empty? ? {} : options
    end

    def type
      @type == :operator ?
        options[:operator] :
        @type
    end

    def to_s
      @options.nil? ?
        "{:#{@type}=>#{@value}}" :
        "{:#{@type}=>#{@value},\n#{options.values.join(",\n")}}"
    end

    def inspect
      @options.nil? ? 
        {@type => @value} :
        [{@type => @value}, *options.values].join(",\n")
    end
  end


  class OperNode < SastNode
    def inspect
      "{#{@value[0]} #{options[:operator]} #{@value[1].to_s}}"
    end
    

    def to_sql
      "#{@value[0].to_sql} #{options[:operator].upcase} #{@value[1].to_sql}"
    end

    def to_s
      "{#{@value[0]} #{options[:operator]} #{@value[1].to_s}}"
    end
  end

  class ConstNode < SastNode
    def inspect
      "{:#{@type}=>#{@value}}"
    end
    
    def to_sql
      @value
    end

    def to_i
      Integer(@value)
    end

    def to_s
      "{:#{@type}=>#{@value}}"
    end
  end 
  
  class QueryNode < SastNode
    def to_sql
      case type
      when :from, :select
        value = @value.map(&:to_sql).join(", ")
      when :join, :where, :limit
        value = @value.to_sql
      end

      # debugger
      
      options = type == :from ? @options[:join] : @options.values

      "#{@type.upcase} #{value} #{options&.map(&:to_sql)&.join(" ")}".chomp(" ")
    end
  end

  class SubQueryNode < QueryNode
    def to_sql
      "(#{@value.to_sql})"
    end
  end
end