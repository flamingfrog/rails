class Post < ActiveRecord::Base
  module NamedExtension
    def author
      'lifo'
    end
  end

  scope :containing_the_letter_a, where("body LIKE '%a%'")
  scope :ranked_by_comments, order("comments_count DESC")
  scope :limit_by, lambda {|l| limit(l) }
  scope :with_authors_at_address, lambda { |address| {
      :conditions => [ 'authors.author_address_id = ?', address.id ],
      :joins => 'JOIN authors ON authors.id = posts.author_id'
    }
  }

  belongs_to :author do
    def greeting
      "hello"
    end
  end

  belongs_to :author_with_posts, :class_name => "Author", :foreign_key => :author_id, :include => :posts
  belongs_to :author_with_address, :class_name => "Author", :foreign_key => :author_id, :include => :author_address

  has_one :last_comment, :class_name => 'Comment', :order => 'id desc'

  scope :with_special_comments, :joins => :comments, :conditions => {:comments => {:type => 'SpecialComment'} }
  scope :with_very_special_comments, joins(:comments).where(:comments => {:type => 'VerySpecialComment'})
  scope :with_post, lambda {|post_id|
    { :joins => :comments, :conditions => {:comments => {:post_id => post_id} } }
  }

  has_many   :comments do
    def find_most_recent
      find(:first, :order => "id DESC")
    end
  end

  has_many :author_favorites, :through => :author

  has_many :comments_with_interpolated_conditions, :class_name => 'Comment',
      :conditions => ['#{"#{aliased_table_name}." rescue ""}body = ?', 'Thank you for the welcome']

  has_one  :very_special_comment
  has_one  :very_special_comment_with_post, :class_name => "VerySpecialComment", :include => :post
  has_many :special_comments
  has_many :nonexistant_comments, :class_name => 'Comment', :conditions => 'comments.id < 0'

  has_many :special_comments_ratings, :through => :special_comments, :source => :ratings

  has_and_belongs_to_many :categories
  has_and_belongs_to_many :special_categories, :join_table => "categories_posts", :association_foreign_key => 'category_id'

  has_many :taggings, :as => :taggable
  has_many :tags, :through => :taggings do
    def add_joins_and_select
      find :all, :select => 'tags.*, authors.id as author_id', :include => false,
        :joins => 'left outer join posts on taggings.taggable_id = posts.id left outer join authors on posts.author_id = authors.id'
    end
  end

  has_many :misc_tags, :through => :taggings, :source => :tag, :conditions => "tags.name = 'Misc'"
  has_many :funky_tags, :through => :taggings, :source => :tag
  has_many :super_tags, :through => :taggings
  has_many :tags_with_primary_key, :through => :taggings, :source => :tag_with_primary_key
  has_one :tagging, :as => :taggable

  has_many :first_taggings, :as => :taggable, :class_name => 'Tagging', :conditions => "taggings.comment = 'first'"
  has_many :first_blue_tags, :through => :first_taggings, :source => :tag, :conditions => "tags.name = 'Blue'"

  has_many :first_blue_tags_2, :through => :taggings, :source => :blue_tag, :conditions => "taggings.comment = 'first'"

  has_many :invalid_taggings, :as => :taggable, :class_name => "Tagging", :conditions => 'taggings.id < 0'
  has_many :invalid_tags, :through => :invalid_taggings, :source => :tag

  has_many :categorizations, :foreign_key => :category_id
  has_many :authors, :through => :categorizations

  has_many :readers
  has_many :readers_with_person, :include => :person, :class_name => "Reader"
  has_many :people, :through => :readers
  has_many :people_with_callbacks, :source=>:person, :through => :readers,
              :before_add    => lambda {|owner, reader| log(:added,   :before, reader.first_name) },
              :after_add     => lambda {|owner, reader| log(:added,   :after,  reader.first_name) },
              :before_remove => lambda {|owner, reader| log(:removed, :before, reader.first_name) },
              :after_remove  => lambda {|owner, reader| log(:removed, :after,  reader.first_name) }
  has_many :skimmers, :class_name => 'Reader', :conditions => { :skimmer => true }
  has_many :impatient_people, :through => :skimmers, :source => :person

  def self.top(limit)
    ranked_by_comments.limit_by(limit)
  end

  def self.reset_log
    @log = []
  end

  def self.log(message=nil, side=nil, new_record=nil)
    return @log if message.nil?
    @log << [message, side, new_record]
  end

  def self.what_are_you
    'a post...'
  end
end

class SpecialPost < Post; end

class StiPost < Post
  self.abstract_class = true
  has_one :special_comment, :class_name => "SpecialComment"
end

class SubStiPost < StiPost
  self.table_name = Post.table_name
end

class PostWithComment < ActiveRecord::Base
  self.table_name = 'posts'
  default_scope where("posts.comments_count > 0").order("posts.comments_count ASC")
end

class PostForAuthor < ActiveRecord::Base
  self.table_name = 'posts'
  cattr_accessor :selected_author
  default_scope lambda { where(:author_id => PostForAuthor.selected_author) }
end
