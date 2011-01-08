#!/home/somnidea/.rvm/bin/gempath_ruby

require 'twitter'
require 'bitly'
require 'words'
require 'active_record'

$dir = File.absolute_path(File.dirname(__FILE__))
require "#{$dir}/gscholar"

ActiveRecord::Base.establish_connection(
	:adapter => "mysql",
	:host => "localhost",
	:database => "hypnoscholar",
	:username => "hypnoscholar",
	:password => "st4lkyp0war"
)

class Tweet < ActiveRecord::Base
	set_table_name 'tweets'
	set_primary_key 'tweet_id'
end

class Message < ActiveRecord::Base
	set_table_name 'messages'
	set_primary_key 'message_id'
end


PREVWORDS_FILE = "#{$dir}/prevwords.dat"

class Hypnoscholar
	def initialize
		# Twitter interface
		Twitter.configure do |config|
			config.consumer_key = "Ba9uuFMLcgd6O0D7hOkIGQ"
			config.consumer_secret = "CW9pL2mKSK1VDoi7sqVuSPxeX0EwU1LRnGGLFTIBwI"
			config.oauth_token = "233160563-5vWd7P2VDqbJueD05lDsW4DzFCXMApR6MDeT2Kqu"
			config.oauth_token_secret = "HRudI6t3GxgbvYKHAOwXVb6ZYI2ZM31bvk5wZmMg"
		end

		Twitter.user('hypnoscholar')

		@twitter = Twitter::Client.new

		# Dictionary interface
		@dict = Words::Wordnet.new
		@dict.open!

		# Bitly interface
		Bitly.use_api_version_3
		@bitly = Bitly.new('somnidea', 'R_3e01b5af02f7232d7ea171aa9df6fdac')
	end


	# Construct a response to a given query
	def make_response(query)
		if query.is_a? Tweet
			sender_name = query.user_screen_name
			content = query.text.gsub(/^@hypnoscholar /, '')
		else
			sender_name = query.sender_screen_name
			content = query.text
		end

		if content[0] == "$" # Shell command!
			if sender_name != 'somnidea'
				resp = "@#{sender_name} is not in the hypnoers file. This incident has been reported."
			else
				resp = `#{content[2..-1]}`
			end
		else
			return nil # Not sure what to do.
		end

		resp = resp.strip
		resp = "@#{sender_name} " + resp unless query.is_a? Message || resp.match(/^@#{sender_name}/)
		resp = resp[0..136] + "..." if resp.strip.length > 140

		return resp
	end

	# Save a copy of this direct message to the database.
	# Assumes it is unprocessed.
	def save_message(mash)
		props = {
			original_id: mash.id,
			text: mash.text,
			sender_screen_name: mash.sender_screen_name,
			recipient_screen_name: mash.recipient_screen_name,
			posted_at: mash.created_at,
		}

		message = Message.find_by_original_id(mash.id)

		if message
			message.update_attributes(props)
		else
			message = Message.new(props)
			message.processed = false
		end

		message.save
	end

	# Saves a copy of a given tweet to the database.
	# Assumes it is unprocessed.
	def save_tweet(mash)
		props = {
			original_id: mash.id,
			user_screen_name: mash.user.screen_name,
			text: mash.text,
			in_reply_to_screen_name: mash.in_reply_to_screen_name,
			in_reply_to_status_id: mash.in_reply_to_status_id,
			source: mash.source,
			posted_at: mash.created_at,
		}

		tweet = Tweet.find_by_original_id(mash.id)

		if tweet
			tweet.update_attributes(props)
		else
			tweet = Tweet.new(props)
			tweet.processed = false
		end

		tweet.save
	end

	# Retrieve and save direct messages for processing
	def retrieve_messages
		params = Message.last.nil? ? {} : {:since_id => Message.last.original_id}
		Twitter.direct_messages(params).each {|mash| save_message(mash)}
	end

	# Retrieve and save mentions for processing.
	def retrieve_mentions
		params = Tweet.last.nil? ? {} : {:since_id => Tweet.last.original_id}
		Twitter.mentions(params).each {|mash| save_tweet(mash)}
	end

	# Go through mentions we haven't responded to yet and see if we can say something.
	def process_messages
		Message.where(:processed => false).each do |message|
			response = make_response(message)
			unless response.nil?
				p response
				@twitter.direct_message_create(message.sender_screen_name, response)
				message.processed = true
				message.save
			end
		end
	end

	# Go through mentions we haven't responded to yet and see if we can say something.
	def process_mentions
		Tweet.where(:processed => false).each do |tweet|
			response = make_response(tweet)
			unless response.nil?
				p response
				@twitter.update(response, :in_reply_to_status_id => tweet.original_id)
				tweet.processed = true
				tweet.save
			end
		end
	end

	# Tweets a random first-page Google Scholar found by search for a word found in 
	# the last 200 tweets of home timeline
	def tweet_scholar_result
		timeline = Twitter.friends_timeline(:count => 200, :include_rts => false)

		prevwords = File.read(PREVWORDS_FILE).split

		words = []

		timeline.each do |tweet|
			words += tweet.text.split.
					reject { |w| ['#','@'].include?(w[0]) || w.match(/^http/) }.
					map { |w| (w.match(/\w+/)||[''])[0].downcase }.
					reject {|w| w.empty? }


		end

		words = words.uniq.sort { |w,w2| w2.length <=> w.length }

		words.each do |word|
			next if prevwords.include?(word) || @dict.find(word).nil?

			results = Scholar.search(word)
			results = results.sample(results.length) # randomize

			result = results.find {|r| r[:text].match(/[a-z]/) && !r[:text].match(/[^\w ]/)}

			next if result.nil?

			link = @bitly.shorten(result[:url]).short_url

			char_alloc = 140-link.length-1

			tweet = "#{result[:text][0..char_alloc]} #{link}"

			puts tweet
			@twitter.update(tweet)

			prevwords << word

			f = File.open(PREVWORDS_FILE, 'w')
			f.write(prevwords.join("\n"))
			f.close

			break
		end
	end
end
