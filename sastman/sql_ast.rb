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
  attr_accessor :default_core
  
  def initialize(value=nil)
    @query = self.class.parse(value) unless value.nil?
    @default_core = true;
  end
  
  def compose(query)
    options = Hash.new { |h,k| h[k] = Array.new }

     

    collect_opts = ->(val) {
      val.value.class == Array ? 
          options[val.type].concat(val.value) :
          (options[val.type] << val.value)
    }
    
    [@query, query].each do |qur|
      qur.options.values.each { |val| 
        collect_opts.call(val)
      }
      collect_opts.call(qur)
    end
    
    # debugger
    composed_query = ""
    [:select, :from, :where, :limit].each do |qur|
      if options.has_key?(qur)
        composed_query += case qur
        when :select, :from
          "#{qur} #{options[qur].map(&:to_sql).join(",")} "
        when :where
          "#{qur} #{options[qur].map(&:to_sql).join(" AND ")} "
        when :limit
          "#{qur} #{options[qur].map(&:to_i).min}"
        end
      end
    end
    
    # puts "composed: #{composed_query}"
    self.class.parse(composed_query)
  end

  def compose!(query)
    @query = self.compose(query)
  end
  
  def to_sql
    @query.to_sql
  end

  def ensure_core(table)
    # check for SELECT and FROM options
    return if @query && @query.type == :select && @query.options.keys.include?(:from)
    return unless @query
    generate_core(table)
  end
  
  private
  def self.parse(query)
    tokens = self.tokenize(query)
    ast = self.generate_tree(tokens)
  end

  def generate_core(table)
    # generate generic SELECT x.* FROM x sast as core utilizing table's info
    if @query && @query.type == :select
      @query.options[:from] = self.class.parse("from #{table.name}")
      return
    elsif @query && @query.type == :from
      new_query = self.class.parse("select #{table.name}.*")
      @default_core = true
    elsif @query && @query.type == :join
      @query = self.class.parse("select #{table.name}.* from #{table.name} #{query.to_sql}")
      @default_core = true
      return
    else
      # where, limit
      new_query = self.class.parse("select #{table.name}.* from #{table.name}")
      @default_core = true
    end

    
    self.compose!(new_query)
  end

  
end
