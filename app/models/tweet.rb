class Tweet < ActiveRecord::Base
    set_table_name 'tweets'
    set_primary_key 'tweet_id'

    has_one :puzzle # Sometimes.
end
