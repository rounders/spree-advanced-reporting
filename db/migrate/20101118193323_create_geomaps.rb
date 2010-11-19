class CreateGeomaps < ActiveRecord::Migration
  def self.up
    create_table :geomaps do |t|
      t.column :name, :string
      t.column :permalink, :string
      t.column :image, :string
      t.column :width, :integer
      t.column :height, :integer
    end
    Geomap.create({ :name => "USA", :permalink => "usa", :image => '/images/advanced_reporting/usa.png', :width => 960, :height => 593 })
    Geomap.create({ :name => "World", :permalink => "world", :image => '/images/advanced_reporting/world.png', :width => 800, :height => 400 })
  end

  def self.down
    drop_table :geomaps
  end
end
