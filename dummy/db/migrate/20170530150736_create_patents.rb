class CreatePatents < ActiveRecord::Migration[5.1]
  def change
    create_table :patents do |t|
      t.string :url

      t.timestamps
    end
  end
end
