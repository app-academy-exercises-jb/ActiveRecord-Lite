module Searchable
  def self.extended(child)
    db = child.db
    table_name = child.table.name
    table_info = child.table.params
    # in this loop, we create a new accessor and find_by_? for each defined attribute
    table_info.each { |k,v|
      key = k.to_s
      method = ("find_by_" + k.to_s).to_sym
      
      # we execute inside our generated class's singleton class in order to make the 'find_by_?' methods class methods
      child.singleton_class.class_exec(db,key,table_name,method) {
        define_method method do |val|
          query = Sast.new_sast("SELECT #{@table.name}.* FROM #{table_name} WHERE #{key}='#{val}'")
          BaseRelation.new(self, query: query)
        end
      }
      # define an accessor for every attribute, for instances of the class
      child.class_exec(k) { attr_accessor k }
      # define klass as self for generated classes
      child.singleton_class.class_exec { def klass; self; end }
    }
  end

  def self.included(child)

  end
  
  def first
    if self.is_a?(BaseRelation) 
      #here we should actually be adding a LIMIT 1 node to the relevant SAST
      self.loaded ?
        values.first :
        (self.load;
        values.first)
    else
      self.all.first
    end
  end

  def all
    query = Sast.new_sast("SELECT #{@table.name}.* FROM #{@table.name}")
    return_relation(query)
  end

  def joins(relation)
    
  end

  def find_by(attribs)
    unless attribs.is_a?(Hash) || attribs.is_a?(String)
      raise ArgumentError.new("expecting a hash or a string")
    end
    
    attribs = attribs.map { |k,v| "#{k} = '#{v}'" }.join(" AND ") if attribs.is_a?(Hash)

    query = Sast.new_sast("SELECT #{@table.name}.* FROM #{@table.name} WHERE #{attribs}")
    return_relation(query)
  end
  alias_method :where, :find_by

  def query(qur_a, qur_b)
    # sql injection attack vector
    query = Sast.new_sast("SELECT #{qur_a} FROM #{@table.name} #{qur_b}")
    return_relation(query)
  end

  private
  def return_relation(query)
    relation = BaseRelation.new(klass, query: query)
    return relation if self.class == Class
    self.relate(relation)
  end
end