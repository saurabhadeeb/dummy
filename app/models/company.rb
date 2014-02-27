class Company < ActiveRecord::Base
  attr_accessible :email_domain, :name
  validates :name, :presence => "true"
  validates :email_domain, :presence => "true"
end
