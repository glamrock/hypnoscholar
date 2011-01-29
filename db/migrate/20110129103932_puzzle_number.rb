class PuzzleNumber < ActiveRecord::Migration
  def self.up
  	change_table :puzzles do |t|
		t.integer :number
	end
  end

  def self.down
  	change_table :puzzles do |t|
		remove_column :number
	end
  end
end
