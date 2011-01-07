require 'cgi'
require 'open-uri'
require 'nokogiri'

def escape(v)
	if v == false; '0'
	elsif v == true; '1'
	else CGI::escape(v.to_s)
	end
end

def parametrize(params)
	paramstrs = []
	params.each { |k,v| paramstrs << "#{k}=#{escape(v)}" unless v.nil? }
	return "?" + paramstrs.join('&')
end

class Scholar
	class << self
		# Returns a hash containing :text and :url of each result on first page.
		def search(query, opthash=nil)
			opts = {
				:citations => false,
				:since => 2008,
			}

			opthash.each {|opt, val| opts[opt] = val} unless opthash.nil?

			scholar = open("http://scholar.google.com/scholar" + parametrize({
				'hl' => 'en',
				'pws' => 0,
				'as_vis' => opts[:citations],
				'as_ylo' => opts[:since],
				'q' => query
			}))

			doc = Nokogiri(scholar.read)

			results = []

			doc.search('.gs_rt a').each do |a|
				results << {
					:text => a.text,
					:url => a.attr('href')
				}
			end

			results
		end
	end
end
