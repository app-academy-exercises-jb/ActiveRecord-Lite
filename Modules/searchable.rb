module Searchable
  def self.extended(child)
    db = child.db
    table_name = child.table.name
    table_info = child.table.params
    # in this loop, we create a new accessor and find_by_? for each defined attribute
    table_info.each { |k,v|
      key = k.to_s
      method = ("find_by_" + k.to_s).to_sym
      
      # we execute inside our generated class's singleton class in order to make the 'find_by_?' methods class methods. these will be eager loading methods, so they do not return a relation
      child.singleton_class.class_exec(db,key,table_name,method) {
        define_method method do |val|
          query = SastMan.new("SELECT #{@table.name}.* FROM #{table_name} WHERE #{key}='#{val}'")
          klass.new(@db.instance.execute(query.to_sql)[0])
        end
        define_method :klass do; self; end
      }
      # define an accessor for every attribute, for instances of the class
      child.class_exec(k) { attr_accessor k }
    }
  end

  def self.included(child)
    # anything necessary for BaseRelations?
  end
  
  # def first
  #   if self.is_a?(BaseRelation) 
  #     #here we should actually be adding a LIMIT 1 node to the relevant SAST
  #     # self.loaded ?
  #     #   values.first :
  #     #   (self.load; values.first)
  #     limit = SastMan.new("LIMIT 1")
  #     self.add_opt(limit)
  #   else
  #     self.all.first
  #   end
  # end

  # def joins(relation)
    
  # end

  def all
    query = SastMan.new("SELECT #{@table.name}.* FROM #{@table.name}")
    return_relation(query)
  end


  def find_by(attribs)
    where(attribs).first
  end

  def where(attribs)
    unless attribs.is_a?(Hash) || attribs.is_a?(String)
      raise ArgumentError.new("expecting a hash or a string")
    end
    
    if attribs.is_a?(Hash)
      attribs = attribs.map { |k,v| "#{k} = '#{v}'" }.join(" AND ") 
    # else
    #   query = attribs
    end
    query = SastMan.new("WHERE #{attribs}")
    debugger
    return_relation(query)
  end

  def select(*attribs)
    unless attribs.all? { |atr| atr.is_a?(Symbol) || atr.is_a?(String) }
      raise ArgumentError.new("expecting strings and symbols only")
    end

    query = SastMan.new("SELECT #{attribs.join(",")}")

    if self.class == BaseRelation && @query.default_core == true
      raise "unexpected relation" if base_query.type != :select
      base_query.value = query.query.value
      @query.default_core = false
      return self
    end

    return_relation(query)
  end

  # def limit
  # def joins
  # def order_by
  # def group_by
  # def having
  
  private
  # def query(qur_a, qur_b)
  #   # sql injection attack vector
  #   query = SastMan.new("SELECT #{qur_a} FROM #{@table.name} #{qur_b}")
  #   return_relation(query)
  # end

  def return_relation(query)
    query.ensure_core(table) if self.class == Class
    relation = BaseRelation.new(klass, query: query)
    return relation if self.class == Class
    self.relate(relation)
  end
end


__END__

reset
require_relative 'base_connection'
BaseConnection.connect('questions.db')
a = User.all;