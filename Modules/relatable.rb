

module Relatable
  class << self
    
  end
  # collective associations generate these methods:
  # #assocs
  # #assocs=
  # #assoc_ids
  # #assoc_ids=(id1,id2...)
  # #assocs <<
  # #assocs.push
  # #assocs.concat


  # valid opts:
  # class_name
  # primary_key
  # foreign_key
  # through
  # source
  def has_many(assocs, scope=nil, **opts)
    if opts[:through]
      source = opts[:source] || assocs #source=user
      klass = Object.const_get(source) #klass=User
      
      foreign_key = opts[:through] #link=question_likes
      
      self.define_method assocs do #:likers
        pk = self.send primary_key.to_sym #pk = Question.inst.id
        full_context = self.class.table.name.to_s + "." + self.class.table.primary_key.to_s
        klass.joins(foreign_key).where("#{full_context} = #{pk}")
        # User.joins(:question_likes).where("questions.id = #")
      end

    else
      table = opts[:class_name] || assocs.to_s.classify 
      klass = Object.const_get(table)  #
      primary_key = opts[:primary_key] || "id" #
      foreign_key = opts[:foreign_key] || self.to_s.singularize.downcase + "_id"  #
      
      self.define_method assocs do
        pk = self.send primary_key.to_sym
        klass.find_by(foreign_key.to_sym => pk)
      end
    end


    self
  end
  # use case for through:
  # class Question
  #   has_many :likers, through: :question_likes, source: :user
  # end
  # when we say Question.first.likers, we want to generate this SQL query:
  # <<-SQL
  #   SELECT
  #     users.*
  #   FROM
  #     users
  #   JOIN
  #     question_likes ON question_likes.liker_id = users.id
  #   WHERE
  #     question_likes.question_id = 1
  # SQL

  # # # usage:
  # load 'base_connection.rb'
  # qs = BaseConnection.new('questions.db')
  # class Question 
  #   belongs_to :author, class_name: "User"
  # end
  # class User
  #   has_many :questions, foreign_key: "author_id"
  # end
  # class QuestionLike
  #   belongs_to :user, class_name: "User", foreign_key: "liker_id"
  #   belongs_to :question
  # end

  # class Question
  #   belongs_to :author, class_name: "User"
  #   has_many :replies
  #   has_many :likers, through: :question_likes
  #   has_many :followers, class_name: :question_follows
  # end
  # class User
  #   has_many :questions, foreign_key: "author_id"
  #   has_many :replies
  #   has_many :followed_questions, through: :question_follows
  #   has_many :liked_questions, through: :question_likes
  # end
  # class Reply
  #   # has_one :parent, class_name: "Reply", foreign_key: "parent_reply_id", optional: true
  #   belongs_to :author, class_name: "User", foreign_key: "user_id"
  #   belongs_to :question
  # end
  # class QuestionFollow
  #   belongs_to :follower, class_name: "User"
  #   belongs_to :question
  # end



  # singular associations generate these methods:
  # #assoc
  # #assoc=

  # valid opts:
  # class_name
  # primary_key
  # foreign_key
  # through
  # source
  # def has_one(assoc, scope=nil, **opts)
  #   # self is the class we are associating from
  #   # has_one :through is the only reason to use

  #   table = opts[:class_name] || assoc.to_s.classify
  #   klass = Object.const_get(table) #User
  #   primary_key = opts[:primary_key] || "id" #id
  #   foreign_key = opts[:foreign_key] || assoc.to_s + "_id" #author_id

  #   self.singleton_class.define_method assoc do
      
  #   end

  # end

  # valid opts:
  # class_name
  # primary_key
  # foreign_key
  def belongs_to(assoc, scope=nil, **opts)
    table = opts[:class_name] || assoc.to_s.classify #User, self is Reply.inst
    klass = Object.const_get(table) #User
    primary_key = opts[:primary_key] || "id" #id
    foreign_key = opts[:foreign_key] || assoc.to_s + "_id" #author_id

    
    self.define_method assoc do
      # relation = BaseRelation.new(self.class, )
      
      fk = self.send foreign_key.to_sym
      klass.find_by(primary_key.to_sym => fk).first
    end

    self.define_method (assoc.to_s + "=").to_sym do |assoc_model|
      raise "fatal" unless assoc_model.class == klass
      pk = assoc_model.send primary_key.to_sym
      self.send (foreign_key + "=").to_sym, pk
    end

    self
  end
end
