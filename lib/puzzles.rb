require 'words'
require 'active_record'

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

			puzzle = Puzzle.new(:text => anagram, :solution => source, :puzzle_type => 'anagram')
			puzzle.save
			puzzle
		end
	end

	set_table_name 'puzzles'
	set_primary_key 'puzzle_id'

	belongs_to :tweet

	def answered_by?(content)
		if solution.words.length > 1
			content.include?(solution)
		else
			content.words.include?(solution)
		end
	end

	def attempted_solutions
		Tweet.where(:in_reply_to_status_id => tweet.original_id)
	end

	def correct_solutions
		attempted_solutions.find_all { |tweet| answered_by?(tweet.text) }
	end
end
