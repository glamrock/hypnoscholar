#!/usr/bin/env ruby

require 'twitter'
require 'bitly'
require 'words'

require './gscholar'

PREVWORDS_FILE = "prevwords.dat"

if __FILE__ == $0
	Dict = Words::Wordnet.new
	Dict.open!

	Twitter.configure do |config|
		config.consumer_key = "Ba9uuFMLcgd6O0D7hOkIGQ"
		config.consumer_secret = "CW9pL2mKSK1VDoi7sqVuSPxeX0EwU1LRnGGLFTIBwI"
		config.oauth_token = "233160563-5vWd7P2VDqbJueD05lDsW4DzFCXMApR6MDeT2Kqu"
		config.oauth_token_secret = "HRudI6t3GxgbvYKHAOwXVb6ZYI2ZM31bvk5wZmMg"
	end

	Twitter.user('hypnoscholar')

	client = Twitter::Client.new

	Bitly.use_api_version_3
	bitly = Bitly.new('somnidea', 'R_3e01b5af02f7232d7ea171aa9df6fdac')

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
		next if prevwords.include?(word) || Dict.find(word).nil?

		results = Scholar.search(word)
		results = results.sample(results.length) # randomize

		result = results.find {|r| r[:text].match(/[a-z]/) && !r[:text].match(/[^\w ]/)}

		next if result.nil?

		link = bitly.shorten(result[:url]).short_url

		char_alloc = 140-link.length-1

		tweet = "#{result[:text][0..char_alloc]} #{link}"

		puts tweet
		client.update(tweet)

		prevwords << word

		f = File.open(PREVWORDS_FILE, 'w')
		f.write(prevwords.join("\n"))
		f.close

		break
	end
end
