#!/home/somnidea/.rvm/bin/gempath_ruby

require 'twitter'
require 'bitly'
require 'words'
require 'active_record'
require 'open-uri'

$dryrun = (`hostname` != 'hypnos')
$creator = 'somnidea'

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

class Logger
	def initialize(logdir)
		@logdir = logdir
		@fdhash = {}

		at_exit do
			@fdhash.each do |cat,fd|
				fd.close
			end
		end
	end

	def log(category, str)
		@fdhash[category] ||= File.open("#{@logdir}/#{sym}.log", 'a')
		@fdhash[category].write(str+"\n")
		@fdhash[category].flush
	end

	def method_missing(sym, *args, &block)
		str = args.join(', ')
		puts "#{sym}: #{str}"
		log(sym, str)
		log(:all, str)
	end
end

class Hypnoscholar
	def initialize
		# Logger
		@log = Logger.new "#{$dir}/../logs"

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

	def construct_response(content, sender_name)
		if content[0] == "$" # Shell command!
			if sender_name != $creator
				return "@#{sender_name} is not in the hypnoers file. This incident has been reported."
			else
				return `#{content[2..-1]}`
			end
		elsif match = content.match(/http:\/\/[^ ]+/)
			doc = Nokogiri(open(match[0]).read)
		else
			return nil # Not sure what to do.
		end
	end


	# Construct a response to a given query
	def assemble_response(query)
		if query.is_a? Tweet
			sender_name = query.user_screen_name
			content = query.text.gsub(/^@hypnoscholar /, '')
		else
			sender_name = query.sender_screen_name
			content = query.text
		end

		begin
			resp = construct_response(content, sender_name)
		rescue Exception => e
			@log.error "Error responding to query `#{query}`: #{e.message}"
			resp = "Sorry, I encountered an error while trying to construct a reply! :("
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

	# Reply to a direct message with the given content.
	def send_reply_to_message(message, response)
		target = message.sender_screen_name
		@twitter.direct_message_create(target, response) unless $dryrun
		@log.message "To @#{target}: #{response}"
		message.processed = true
		message.save
	end

	# Reply to a tweet with the given content.
	def send_reply_to_tweet(tweet, response)
		@twitter.update(response, :in_reply_to_status_id => tweet.original_id) unless $dryrun
		@log.tweet response
		tweet.processed = true
		tweet.save
	end

	# Update with given content.
	def update(content)
		@log.tweet content
		@twitter.update(content) unless $dryrun
	end

	# Go through mentions we haven't responded to yet and see if we can say something.
	def process_messages
		Message.where(:processed => false).each do |message|
			response = assemble_response(message)
			send_reply_to_message(message, response) unless response.nil?
		end
	end

	# Go through mentions we haven't responded to yet and see if we can say something.
	def process_mentions
		Tweet.where(:processed => false).each do |tweet|
			response = assemble_response(tweet)
			send_reply_to_tweet(tweet, response) unless response.nil?
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

			update(tweet)

			prevwords << word

			f = File.open(PREVWORDS_FILE, 'w')
			f.write(prevwords.join("\n"))
			f.close

			break
		end
	end
end
