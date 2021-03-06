
class String
    def words
        self.scan(/[\w']+/).map {|w| w.downcase}
    end
end

ENV['RAILS_ENV'] = (`hostname`.strip == 'hypnos' ? 'production' : 'development')

# Load the rails application
require File.expand_path('../application', __FILE__)
require File.expand_path('../..//lib/gtranslate', __FILE__)
require File.expand_path('../../lib/gscholar', __FILE__)


# Initialize the rails application
Hypnoscholar::Application.initialize!

