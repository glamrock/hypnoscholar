require File.expand_path('../boot', __FILE__)

require 'rails/all'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

$dryrun = (`hostname`.strip != 'hypnos')
$creator = 'somnidea'

$dir = File.absolute_path(File.dirname(__FILE__))
PREVWORDS_FILE = "#{$dir}/../db/prevwords.dat"


require 'twitter'
require 'bitly'
require 'words'
require 'open-uri'
require 'curl'

module Dict
    class << self
        def method_missing(sym, *args, &block)
            unless @dict
                @dict ||= Words::Wordnet.new
                @dict.open!
            end

            @dict.send(sym, *args, &block)
        end
    end
end

module TwitterAPI
    class << self
        def method_missing(sym, *args, &block)
            unless @twitter
                # Twitter interface
                Twitter.configure do |config|
                    config.consumer_key = "Ba9uuFMLcgd6O0D7hOkIGQ"
                    config.consumer_secret = "CW9pL2mKSK1VDoi7sqVuSPxeX0EwU1LRnGGLFTIBwI"
                    config.oauth_token = "233160563-5vWd7P2VDqbJueD05lDsW4DzFCXMApR6MDeT2Kqu"
                    config.oauth_token_secret = "HRudI6t3GxgbvYKHAOwXVb6ZYI2ZM31bvk5wZmMg"
                end

                Twitter.user('hypnoscholar')

                @twitter = Twitter::Client.new
            end

            if @twitter.respond_to? sym
                @twitter.send(sym, *args, &block)
            else
                Twitter.send(sym, *args, &block)
            end
        end
    end
end

module LinkShortener
    class << self
        def method_missing(sym, *args, &block)
            unless @bitly
                Bitly.use_api_version_3
                @bitly = Bitly.new('somnidea', 'R_3e01b5af02f7232d7ea171aa9df6fdac')
            end

            @bitly.send(sym, *args, &block)
        end
    end
end

module Log
    class << self
        def method_missing(sym, *args, &block)
            str = args.join(', ')
            puts "#{sym}: #{str}"
			Rails.logger.send(sym, str)
        end
    end
end

module Hypnoscholar
    class << self
        ### Utility Methods

        def word_frequencies(text)
            fmap = {}
            words = text.words
            words.uniq.each do |w|
                fmap[w] = words.count(w)/words.length.to_f
            end
            fmap
        end


        # Truncate a given string to fit within the character limit, adding '...' as required.
        def truncate(str, charlimit, terminator='...')
            if str.length <= charlimit
                str
            else
                str[0..(charlimit-terminator.length-1)] + terminator
            end
        end

        # Determine if a string of text is sciency or not. Currently not very sophisticated.
        def is_sciency?(text)
            !text.downcase.match(/scien|logy|sophy|tech|comput|pokemon/).nil?
        end

        ### Local Data Retrieval Methods

        def last_tweet
            Tweet.where({:user_screen_name => 'hypnoscholar'}, :order => "posted_at ASC").last
        end

        def last_update
            Tweet.where({:user_screen_name => 'hypnoscholar', :in_reply_to_screen_name => nil}, :order => "posted_at DESC").first
        end

        def tweeted_puzzles
            Puzzle.where("tweet_id IS NOT NULL")
        end

        def last_tweeted_puzzle
            tweeted_puzzles.sort { |x, y| y.tweet.posted_at <=> x.tweet.posted_at }.first
        end

        def time_of_last_update
            last_tweet ? last_tweet.posted_at : (Time.new - Time.new.to_f)
        end

        def can_update_again_yet?
            (Time.now - time_of_last_update) > 60*60
        end

        def unprocessed_messages
            Message.where(:recipient_screen_name => 'hypnoscholar', :processed => false)
        end

        def unprocessed_mentions
            Tweet.where(:in_reply_to_screen_name => 'hypnoscholar', :processed => false)
        end

        ### Response Construction Methods

        # Generate tweet with a short title and a bitly link.
        def make_link_tweet(title, longlink, via=nil)
			if longlink.match(/http:\/\/bit\.ly/)
				link = longlink
			else 
				link = LinkShortener.shorten(longlink).short_url
			end
            viastr = " (via @#{via})"

            title_constraint = 140-link.length-1
            title_constraint -= viastr.length unless via.nil?
            return "#{truncate(title, title_constraint)} #{link}" + (via.nil? ? '' : viastr)
        end

        # Retrieve the first noun from the array of words given.
        def find_noun(words)
            words.find { |w| lemma = Dict.find(w); lemma && !lemma.nouns.empty? }
        end

        def tweetable_fortune(length=120)
            `/usr/games/fortune -s -n #{length}`.gsub(/[\n\t]/, ' ').gsub(/--.+$/, '').strip.gsub(/\s+/, ' ').gsub('.', '!')
        end

        # These are just plain random replies based on whatever hypnoscholar feels like.
        def random_reply_tweet(content)
            rn = rand

            if content
                words = content.words
                word = find_noun(words.sample(words.length))
            end

            if rn < 0.4 && word
                definition_tweet(word)
            elsif rn < 0.95
                content.bad_translate.gsub('.', '!')
            else
                tweetable_fortune
            end
        end

        # Tweet a definition of the given noun.
        def definition_tweet(word)
            definition = nil

            lemma = Dict.find(word)

            lemma.nouns.each do |noun|
                definition = noun.gloss if definition.nil? || noun.gloss.length < definition.length
            end

            "A #{word} is #{definition}!"
        end

        # Generates tweet with random information related to a document. Mostly.
        def random_page_related_tweet(doc, content=nil)
            words = doc.text.words
            words = words.reject {|w| w.length < 5 || words.count(w) < 2}

            lemma = nil
            word = find_noun(words.sample(words.length))
            rn = rand

            if rn < 0.05
                ele = ['p', 'div', 'script', 'img'].sample
                "Did you know that page has #{doc.css(ele).length} <#{ele}> tags? :o"
            elsif rn < 0.1
                "That page uses the word '#{word}' #{words.count(word)} times!"
            elsif rn < 0.9
                definition_tweet(word)
            else
                random_reply_tweet(content)
            end
        end

        def following?(screen_name)
            TwitterAPI.friendship_exists?('hypnoscholar', screen_name)
        end

        def construct_response(content, sender_name, query, origin=nil)
            if content[0] == "$"
                # Shell Command
                if sender_name != $creator
                    return "@#{sender_name} is not in the hypnoers file. This incident has been reported."
                else
                    return `#{content[2..-1]}`
                end

            elsif !origin.nil? && origin.puzzle
                # Puzzle Answer!
                puzzle = origin.puzzle

                incorrect = ["Incorrect, sorry!", "Nope!", "Try again!", "Better luck next time!"]
                correct = ["Correct! ^_^", "Good job!", "That's right! :D", "Well done!"]

                return "You can't answer your own puzzle!" if puzzle.author_screen_name == sender_name

                return incorrect.sample unless puzzle.answered_by?(content)

                if puzzle.correct_solutions.length == 1 # First correct answer!
                    update "First correct answer for Puzzle #{puzzle.number} goes to: @#{sender_name}!"
                    return false
                else
                    return correct.sample
                end

            elsif query.is_a?(Message) && content.match(/Q:/)
                # Puzzle contribution!
                return "You'll have to solve a few more puzzles before you can add your own, I'm afraid!" unless following?(sender_name)

                match = content.match(/Q: (.+) A: (.+)$/)

                return "That's not how you make a puzzle. You need both a \"Q:\" and an \"A:\"." if match.nil?

                mocktweet = "Puzzle #{Puzzle.last.id} (by @#{sender_name}): " + match[1]

                return "Sorry, that puzzle is #{mocktweet.length-140} characters too long >.<" if mocktweet.length > 140

                puzzle = Puzzle.new(:author_screen_name => sender_name, :text => match[1],
                                    :solution => match[2], :puzzle_type => 'special')

                puzzle.save

                return "Acknowledged! Your contribution will be listed as Puzzle #{puzzle.number} ^_^"

            elsif match = content.match(/http:\/\/[^ ]+/)
                # Interesting link?
                link = match[0]
                resp = Curl::Easy.http_get(link) { |easy| easy.follow_location = true }
                doc = Nokogiri(resp.body_str)

                title = doc.css('title').text

                if is_sciency?(title) && can_update_again_yet?
                    update make_link_tweet(title, link, sender_name)
                    return false # Processed successfully, no need for reply.
                else
                    return random_page_related_tweet(doc, content)
                end
            else
                random_reply_tweet(content)
            end
        end

        def find_or_retrieve_tweet(original_id)
            return nil unless original_id
            tweet = Tweet.find_by_original_id(original_id)
            tweet = save_tweet(TwitterAPI.status(original_id)) if tweet.nil?
            tweet
        end

        def assemble_response(query)
            if query.is_a? Tweet
                sender_name = query.user_screen_name
                content = query.text.gsub(/^@hypnoscholar /, '')
                origin = find_or_retrieve_tweet(query.in_reply_to_status_id)
            else
                sender_name = query.sender_screen_name
                content = query.text
                origin = nil
            end

            begin
                resp = construct_response(content, sender_name, query, origin)
            rescue Exception => e
                Log.error "Error responding to query `#{content}`: #{e.message}\n  #{e.backtrace[0]}"
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


        ### Local Data Storage Methods

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
            message
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
            tweet
        end



        ### Remote Data Retrieval Methods

        # Retrieve and save direct messages for processing
        def retrieve_messages
            params = Message.last.nil? ? {} : {:since_id => Message.last.original_id}
            TwitterAPI.direct_messages(params).each {|mash| save_message(mash)}
        end

        # Retrieve and save mentions for processing.
        def retrieve_mentions
            params = Tweet.last.nil? ? {} : {:since_id => Tweet.last.original_id}
            TwitterAPI.mentions(params).each {|mash| save_tweet(mash)}
        end

        # Retrieve and save local copies of our own tweets for reference.
        def retrieve_own_timeline
            params = last_tweet.nil? ? {} : {:since_id => last_tweet.posted_at}
            TwitterAPI.user_timeline('hypnoscholar', params).each {|mash| save_tweet(mash)}
        end

        # Retrieve and save local copies of home timeline tweets
        def retrieve_home_timeline
            last = Tweet.where({}, :order => "posted_at ASC").last
            params = { :count => 200 }
            params[:since_id] = last.posted_at unless last.nil?
            TwitterAPI.user_timeline('hypnoscholar', params).each {|mash| save_tweet(mash)}
        end

        ### Low-Level Update Methods

        # Reply to a direct message with the given content.
        def send_reply_to_message(message, response)
            unless response == false
                target = message.sender_screen_name
                TwitterAPI.direct_message_create(target, response) unless $dryrun
                Log.info "To @#{target}: #{response}"
            end

            unless $dryrun
                message.processed = true
                message.save
            end
        end

        # Reply to a tweet with the given content.
        def send_reply_to_tweet(tweet, response)
            unless response == false
                TwitterAPI.update(response, :in_reply_to_status_id => tweet.original_id) unless $dryrun
                Log.info response
            end

            unless $dryrun
                tweet.processed = true
                tweet.save
            end
        end

        # Update with given content.
        def update(content)
            Log.info content
            unless $dryrun
                save_tweet(TwitterAPI.update(content))
            end
        end



        ### High-Level Update Generators

        # Go through mentions we haven't responded to yet and see if we can say something.
        def process_messages
            unprocessed_messages.each do |message|
                response = assemble_response(message)
                send_reply_to_message(message, response) unless response.nil?
            end
        end

        # Go through mentions we haven't responded to yet and see if we can say something.
        def process_mentions
            unprocessed_mentions.each do |tweet|
                response = assemble_response(tweet)
                send_reply_to_tweet(tweet, response) unless response.nil?
            end
        end

          # TwitterAPI a random first-page Google Scholar found by search for a word found in 
        # the last 200 tweets of home timeline
        def tweet_scholar_result
            timeline = TwitterAPI.friends_timeline(:count => 200, :include_rts => false)

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

                update make_link_tweet(result[:text], result[:url])


                prevwords << word

                f = File.open(PREVWORDS_FILE, 'w')
                f.write(prevwords.join("\n"))
                f.close

                break
            end
        end

        # Generate a puzzle for tweeting.
        def generate_puzzle(puzzle_type='random')
            possibilities = {}

            last_puzzle_type = Puzzle.last.nil? ? nil : Puzzle.last.puzzle_type

            ['binarygram', 'anagram', 'dnagram'].each do |puzzle_type|
                possibilities[puzzle_type] = Proc.new {
                    tweets = Tweet.where({}, :limit => 200, :order => "posted_at DESC")
                    words = tweets.map { |tweet| tweet.text }.join(' ').words
                    Puzzle.send(puzzle_type, words)
                }
            end

            possibilities['cryptogram'] = Proc.new { Puzzle.cryptogram(tweetable_fortune(100)) }

            if puzzle_type != 'random'
                possibilities[puzzle_type].call
            else
                possibilities.reject { |k| k == last_puzzle_type }.values.sample.call
            end

        end

        # Tweet the next puzzle in sequence.
        def tweet_puzzle
            puzzle = Puzzle.where(:tweet_id => nil).first
            puzzle = generate_puzzle if puzzle.nil?

            unless puzzle.nil?
				puzzle.number = last_tweeted_puzzle.number+1
                puzzline = "Puzzle #{puzzle.number}"

                if puzzle.author_screen_name
                    puzzline += " (by @#{puzzle.author_screen_name})"
                elsif puzzle.puzzle_type == 'special'
                    puzzline += " (Special)"
                end

                tweet_text = "#{puzzline}: #{puzzle.text}"

                tweet_text += " ##{puzzle.puzzle_type}" unless puzzle.puzzle_type == 'special'

                tweet = update(tweet_text)
                if tweet.is_a? Tweet
                    puzzle.tweet = tweet
                    puzzle.save unless $dryrun
                end
            end
        end
    end

    class Application < Rails::Application
        # Settings in config/environments/* take precedence over those specified here.
        # Application configuration should go into files in config/initializers
        # -- all .rb files in that directory are automatically loaded.

        # Custom directories with classes and modules you want to be autoloadable.
        # config.autoload_paths += %W(#{config.root}/extras)

        # Only load the plugins named here, in the order given (default is alphabetical).
        # :all can be used as a placeholder for all plugins not explicitly named.
        # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

        # Activate observers that should always be running.
        # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

        # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
        # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
        # config.time_zone = 'Central Time (US & Canada)'

        # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
        # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
        # config.i18n.default_locale = :de

        # JavaScript files you want as :defaults (application.js is always included).
        # config.action_view.javascript_expansions[:defaults] = %w(jquery rails)

        # Configure the default encoding used in templates for Ruby 1.9.
        config.encoding = "utf-8"

        # Configure sensitive parameters which will be filtered from the log file.
        config.filter_parameters += [:password]
    end
end
