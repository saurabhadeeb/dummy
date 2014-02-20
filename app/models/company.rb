class Company < ActiveRecord::Base
  has_many :users
  attr_accessible :name, :email_domain
  validates :name, :presence => true
  validates :email_domain, :presence => true
  validate :check_begin_with_at_sign
  
  def check_begin_with_at_sign
    if !self.email_domain.blank? and !self.email_domain.start_with?("@")
        errors.add(:email_domain,"not in proper format.")
      end
end

  
end

