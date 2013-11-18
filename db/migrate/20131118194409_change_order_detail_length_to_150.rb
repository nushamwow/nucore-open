class ChangeOrderDetailLengthTo150 < ActiveRecord::Migration
  def up
    change_column :order_details, :note, :string, :limit => 150
  end

  def down
    change_column :order_details, :note, :string, :limit => 100
  end
end
