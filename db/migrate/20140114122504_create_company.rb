class CreateCompany < ActiveRecord::Migration
  def change
    create_table :companies do |c|
      c.string :name
      c.string :email_domain
      c.timestamps
    end
  end
end
