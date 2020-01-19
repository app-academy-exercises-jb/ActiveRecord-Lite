require 'byebug'
require 'singleton'
require 'sqlite3'
require 'active_support/inflector'


require_relative 'base_object'
require_relative 'base_table'
require_relative "base_relation"
require_relative 'Modules/relatable'
require_relative 'Modules/validator'
require_relative 'Modules/equalizer'
require_relative 'Modules/finalizer'
require_relative 'Modules/searchable'
require_relative "sast/sql_ast"

class BaseConnection
  def initialize(connection)
    raise "#{connection} not a valid file name" unless File.exist?(connection)
    
    @db = BaseConnection.connect(connection)
    classes = BaseConnection.discover_classes(@db)    
    @generated_classes = BaseConnection.populate_classes!(@db, classes)
  end

  class << self
    def connect(connection)
      Class.new SQLite3::Database do
        include Singleton

        define_method :initialize do
          super connection
          self.type_translation = true
          self.results_as_hash = true
        end
      end
    end

    def discover_classes(db)
      #discover our tables to prep our object creation
      tables = []
      db.instance.execute("SELECT name FROM sqlite_master").each { |table|
        tables << table['name']
      }
      tables
    end

    def populate_classes!(db, tables)
      #here we will define a new class for every table
      classes = []

      tables.each { |table_name|
        next if /^sqlite_/.match?(table_name) #we don't want sqlite internal tables
        
        table = BaseTable.new(table_name, *db.instance.execute("PRAGMA table_info(#{table_name})"))
        
        # debugger
        # each new class gets a pointer back to the db connection
        # as well as parsed table information
        klass = Object.const_set(table_name.classify, Class.new(BaseObject) {
          self.instance_variable_set(:@db, db)
          self.instance_variable_set(:@table, table)

          def self.db; @db; end
          def self.table; @table; end
          def db; self.class.instance_variable_get(:@db); end
          def table; self.class.instance_variable_get(:@table); end

          extend Finalizer
          extend Relatable
          extend Validator
          extend Searchable
          include Equalizer
        })

        classes << klass
      }

      classes
    end
  end
end