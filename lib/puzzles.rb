require 'words'
require 'active_record'

PUZZLE_ANAGRAM = 0

class Puzzle < ActiveRecord::Base
	class << self
		def longest_words(words)
			maxlen = words.sort { |x,y| y.length <=> x.length }.first.length
			words.find_all { |w| w.length == maxlen }
		end

		def anagram(source)
			if source.is_a? Array
				longwords = longest_words(source)
				source = longwords.sample(longwords.length).find { |word| !Dict.find(word).nil? }
			end

			anagram = source.chars.to_a.sample(source.length).join

			puzzle = Puzzle.new(:content => anagram, :solution => source, :puzzle_type => 'anagram')
			puzzle.save
			puzzle
		end
	end

	set_table_name 'puzzles'
	set_primary_key 'puzzle_id'

	belongs_to :tweet

	def attempted_solutions
		Tweet.where(:in_reply_to_status_id => tweet.id)
	end
end
