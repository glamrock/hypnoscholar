require 'words'
require 'active_record'

class Puzzle < ActiveRecord::Base
	class << self
		def longest_words(words)
			maxlen = words.sort { |x,y| y.length <=> x.length }.first.length
			words.find_all { |w| w.length == maxlen }
		end

		def one_string(source)
			return source unless source.is_a? Array
			source.sample(source.length).reject {|word| word.length < 9}.
						find { |word| !Dict.find(word).nil? }
		end

		def subcipher(source, alternatives)
			cipher = {}; alphabet = ('a'..'z').to_a

			0.upto(alphabet.length) {|i| cipher[alphabet[i]] = alternatives[i]}

			source.downcase.chars.map { |ch| cipher[ch]||ch }.join
		end

		# Basic substitution cipher
		def cryptogram(source)
			source = one_string(source).downcase

			alphabet = ('a'..'z').to_a
			crypted = subcipher(source, alphabet.sample(alphabet.length))

			Puzzle.new(:text => crypted, :solution => source, :puzzle_type => 'cryptogram')
		end

		# Randomized DNA codon substitution cipher
		def dnagram(source)
			source = one_string(source).downcase

			reserved = ['ATG', 'TAA', 'TAG', 'TGA']
			codons = ['A', 'T', 'C', 'G'].repeated_permutation(3).to_a
			codons = codons.sample(codons.length) - reserved

			Puzzle.new(:text => subcipher(source, codons), :solution => source, :puzzle_type => 'dnagram')
		end

		# Standard one-word anagram.
		def anagram(source)
			source = one_string(source)

			anagram = source.chars.to_a.sample(source.length).join

			Puzzle.new(:text => anagram, :solution => source, :puzzle_type => 'anagram')
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
