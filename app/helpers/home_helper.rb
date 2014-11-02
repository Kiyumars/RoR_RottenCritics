module HomeHelper

end

require 'json'
require 'uri'

require 'net/http'

TMDB_key = ENV['tmdb_key']
RT_key = ENV['rt_key']

module HomeHelper	
end

def prepare_actor_url_parameter_for_tmdb(actor_name_list)
	url_parameter = "&query=" + actor_name_list.join("+")
end


def search_tmdb_for_actor_and_filmography(actor_parameter)
	search_actor = request_tmdb_json("search/person", actor_parameter)
	actor_id = search_actor['results'][0]['id'].to_s
	actor_biography_request_url = "person/" + actor_id 
	request_tmdb_json(actor_biography_request_url)['biography']
	# actor_filmography_request_url = "person/" + actor_id + "/movie_credits"
	# return request_tmdb_json(actor_filmography_request_url)
end


def request_tmdb_json(request_type_url, extra_url='')
	request_url = "http://api.themoviedb.org/3/"
	request_url += request_type_url
	request_url += "?api_key="
	request_url += TMDB_key
	request_url += extra_url

	resp = Net::HTTP.get_response(URI(request_url))
	return JSON(resp.body)
end
