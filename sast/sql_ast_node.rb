class Sast
  class SastNode
    attr_reader :value, :options
    # attr_accessor :next, :prev
    # redefine self.new in order to return different types of nodes based on the options being passed in 
    def initialize(type:, value: nil, child: nil, options:{})
      @type = type
      @value = value
      @options = options unless options.empty?
    end

    def type
      @type == :operator ?
        options[:operator] :
        @type
    end

    def to_s
      if @type == :operator
        "{#{@value[0]} #{options[:operator]} #{@value[1].to_s}}"
      # elsif type == :query
      #   "{:#{@type}=>#{@value},\n#{options.values.join(",\n")}}"
      else
        @options.nil? ?
          "{:#{@type}=>#{@value}}" :
          "{:#{@type}=>#{@value},\n#{options.values.join(",\n")}}"
      end
    end

    def inspect
      if @type == :operator
        "{#{@value[0]} #{options[:operator]} #{@value[1].to_s}}"
      # elsif type == :query
      #   "{:#{@type}=>#{@value},\n#{options.values.join(",\n")}}"
      else
        @options.nil? ? 
          {@type => @value} :
          [{@type => @value}, *options.values].join(",\n")
      end
    end
  end
end