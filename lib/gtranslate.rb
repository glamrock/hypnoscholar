require 'cgi'
require 'open-uri'
require 'json'

API_KEY = "AIzaSyAt-DzStk_hdwPSpjTKLo_x86Zor-GPNSs"

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

class String
	def translate(from, to)
		json = open("https://www.googleapis.com/language/translate/v2" + parametrize({
			'key' => API_KEY,
			'q' => self,
			'source' => from,
			'target' => to
		})).read

		JSON.parse(json)['data']['translations'][0]['translatedText'].gsub("&#39;", "'")
	end

	def translate_to(to)
		translate(nil, to)
	end

	def translate_sequence(*seq)
		s = self;
		1.upto(seq.length-1) do |i|
			s = s.translate(seq[i-1], seq[i])
		end
		s
	end

	def bad_translate
		#translate_sequence('en', 'af', 'sq', 'ar', 'be', 'bg', 'ca', 'zh-CN', 'zh-TW', 'hr', 'cs', 'da', 'en')
		translate_sequence('en', 'af', 'yi', 'cy', 'vi', 'uk', 'tr', 'th', 'sv', 'sw', 'es', 'sl', 'sk', 'sr', 'ru', 'zh-CN', 'en')
	end
end
