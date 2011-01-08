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
		@fdhash[category] ||= File.open("#{@logdir}/#{category}.log", 'a')
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

	# Determine if a string of text is sciency or not. Currently not very sophisticated.
	def is_sciency?(text)
		text.downcase.include?('scien')
	end

	# What was our last tweet?
	def last_tweet
		Tweet.where({:user_screen_name => 'hypnoscholar'}, :order => "posted_at ASC").last
	end

	# What was our last non-reply tweet?
	def last_update
		Tweet.where({:user_screen_name => 'hypnoscholar', :in_reply_to_screen_name => nil}, :order => "posted_at ASC").last
	end

	# When did we last post a non-reply tweet?
	def time_of_last_update
		last_tweet ? last_tweet.posted_at : (Time.new - Time.new.to_f)
	end

	# Can we post another non-reply tweet now?
	def can_update_again_yet?
		(Time.now - time_of_last_tweet) > 60*60
	end

	def construct_response(content, sender_name)
		if content[0] == "$"
			# Shell Command
			if sender_name != $creator
				return "@#{sender_name} is not in the hypnoers file. This incident has been reported."
			else
				return `#{content[2..-1]}`
			end

		elsif match = content.match(/http:\/\/[^ ]+/)
			# Interesting link?
			link = match[0]
			doc = Nokogiri(open(link).read)

			title = doc.css('title').text

			if is_sciency?(title) && can_update_again_yet?
				update make_link_tweet(title, link, sender_name)
				return false # Processed successfully, no need for reply.
			end
		else
			return nil # Not sure what to do.
		end
	end


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
			@log.error "Error responding to query `#{content}`: #{e.message}"
			#resp = "Sorry, I encountered an error while thinking about how to reply! :("
			resp = nil
		end

		if resp
			resp = resp.strip
			resp = "@#{sender_name} " + resp unless query.is_a? Message || resp.match(/^@#{sender_name}/)
			resp = truncate(resp, 140)
		end

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

	# Retrieve and save local copies of our own tweets for reference.
	def retrieve_own_timeline
		params = last_tweet.nil? ? {} : {:since_id => last_tweet.posted_at}
		Twitter.user_timeline('hypnoscholar', params).each {|mash| save_tweet(mash)}
	end

	# Reply to a direct message with the given content.
	def send_reply_to_message(message, response)
		unless response == false
			target = message.sender_screen_name
			@twitter.direct_message_create(target, response) unless $dryrun
			@log.message "To @#{target}: #{response}"
		end

		unless $dryrun
			message.processed = true
			message.save
		end
	end

	# Reply to a tweet with the given content.
	def send_reply_to_tweet(tweet, response)
		unless response == false
			@twitter.update(response, :in_reply_to_status_id => tweet.original_id) unless $dryrun
			@log.tweet response
		end

		unless $dryrun
			tweet.processed = true
			tweet.save
		end
	end

	# Update with given content.
	def update(content)
		@log.tweet content
		unless $dryrun
			@twitter.update(content)
			retrieve_own_timeline	
		end
	end

	# Truncate a given string to fit within the character limit, adding '...' as required.
	def truncate(str, charlimit)
		if str.length <= charlimit
			str
		else
			str[0..(charlimit-3-1)] + '...'
		end
	end

	# Generate tweet with a short title and a bitly link.
	def make_link_tweet(title, longlink, via=nil)
		link = @bitly.shorten(longlink).short_url
		viastr = " (via @#{via})"

		title_constraint = 140-link.length-1
		title_constraint -= viastr.length unless via.nil?
		return "#{truncate(title, title_constraint)} #{link}" + (via.nil? ? '' : viastr)
	end

	def unprocessed_messages
		Message.where(:recipient_screen_name => 'hypnoscholar', :processed => false)
	end

	# Go through mentions we haven't responded to yet and see if we can say something.
	def process_messages
		unprocessed_messages.each do |message|
			response = assemble_response(message)
			send_reply_to_message(message, response) unless response.nil?
		end
	end

	def unprocessed_mentions
		Tweet.where(:in_reply_to_screen_name => 'hypnoscholar', :processed => false)
	end

	# Go through mentions we haven't responded to yet and see if we can say something.
	def process_mentions
		unprocessed_mentions.each do |tweet|
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

			update make_link_tweet(result[:text], result[:url])


			prevwords << word

			f = File.open(PREVWORDS_FILE, 'w')
			f.write(prevwords.join("\n"))
			f.close

			break
		end
	end
end
