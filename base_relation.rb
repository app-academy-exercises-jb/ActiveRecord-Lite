# Information a relation should have:
# table information
# klass information
# whether it has been loaded
# official signature:
# ::new(klass, table: klass.arel_table, predicate_builder: klass.predicate_builder, values: {})

require_relative "Modules/searchable"

class BaseRelation
  attr_reader :loaded, :klass

  include Searchable

  def initialize(klass, table: klass.table, db: klass.db, query: nil, values: {})
    @klass = klass
    @db = db
    @table = table
    @query = query
    @values = values
    @loaded = false
  end

  def load
    puts @query.to_sql
    @values = @db.instance.execute @query.to_sql
    @loaded = true

    self.konstruct
  end

  def relate(relation)
    raise "expected #{relation} to be a BaseRelation" unless relation.is_a?(BaseRelation)
    begin
      @query.compose!(relation)
    rescue => exception
      puts exception.message
    end
    self
  end
  
  def values
    loaded ? 
      @konstructed :
      nil
  end

  def konstruct
    @konstructed = @values.map { |val| @klass.new(val) }
  end

  def inspect
    case @loaded
    when false
      self.load
    when true
      @konstructed
    end
  end
end