# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110129103932) do

  create_table "messages", :primary_key => "message_id", :force => true do |t|
    t.integer  "original_id",           :limit => 8,                    :null => false
    t.string   "text",                                                  :null => false
    t.string   "sender_screen_name",                                    :null => false
    t.string   "recipient_screen_name",                                 :null => false
    t.datetime "posted_at",                                             :null => false
    t.boolean  "processed",                          :default => false, :null => false
  end

  add_index "messages", ["original_id"], :name => "original_id", :unique => true

  create_table "puzzles", :primary_key => "puzzle_id", :force => true do |t|
    t.integer "tweet_id"
    t.string  "text",               :null => false
    t.string  "solution"
    t.string  "puzzle_type",        :null => false
    t.string  "author_screen_name"
    t.integer "number"
  end

  create_table "tweets", :primary_key => "tweet_id", :force => true do |t|
    t.integer  "original_id",             :limit => 8,                    :null => false
    t.string   "user_screen_name",                                        :null => false
    t.string   "text",                                                    :null => false
    t.string   "in_reply_to_screen_name"
    t.integer  "in_reply_to_status_id",   :limit => 8
    t.string   "source",                                                  :null => false
    t.datetime "posted_at",                                               :null => false
    t.boolean  "processed",                            :default => false, :null => false
  end

  add_index "tweets", ["original_id"], :name => "original_id", :unique => true

end
