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

ActiveRecord::Schema.define(:version => 20110119124116) do

  create_table "messages", :force => true do |t|
    t.integer  "message_id"
    t.integer  "original_id"
    t.string   "text"
    t.string   "sender_screen_name"
    t.string   "recipient_screen_name"
    t.datetime "posted_at"
    t.boolean  "processed"
  end

  create_table "puzzles", :force => true do |t|
    t.integer "puzzle_id"
    t.integer "tweet_id"
    t.string  "text"
    t.string  "solution"
    t.string  "puzzle_type"
    t.string  "author_screen_name"
  end

  create_table "tweets", :force => true do |t|
    t.integer  "tweet_id"
    t.integer  "original_id"
    t.string   "user_screen_name"
    t.string   "text"
    t.string   "in_reply_to_screen_name"
    t.integer  "in_reply_to_status_id"
    t.string   "source"
    t.datetime "posted_at"
    t.boolean  "processed"
  end

end
