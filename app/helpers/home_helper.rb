require 'json'
require 'uri'

require 'net/http'
require "mongo"

TMDB_key = ENV['tmdb_key']
RT_key = ENV['rt_key']

module HomeHelper	
end


def start_game_session(players, actor_id)
	db = Mongo::Connection.new.db("mydb")
	coll = db.collection('game_sessions')
	movies = get_movies_from_actor_db(actor_id)
	players_hash = Hash.new

	players.each do |player|
		players_hash[player] = 0
	end

	game_id = coll.insert("players_scores" => players_hash,
							 "players_guesses" => players_hash, 
							 "movies" => movies,
							 "critics_score" => nil)
end


def get_movies_from_actor_db(actor_id)
	db = Mongo::Connection.new.db("mydb")
	actor_db = db.collection('actors_tmdb')

	actor_query = actor_db.find_one("_id" => BSON::ObjectId(actor_id.to_s))
	movies = actor_query['movies']
end


def check_if_actor_in_db(actor_name)
	db = Mongo::Connection.new.db("mydb")
	coll = db.collection('actors_tmdb')
	find_actor = coll.find_one('actor_name' => actor_name)
	if find_actor.nil? then
		return false
	else
		return find_actor
	end	
end

def prepare_actor_url_parameter_for_tmdb(actor_name_list)
	url_parameter = "&query=" + actor_name_list.join("+")
end


def search_tmdb_for_actor_and_return_filmography(actor_parameter)
	search_actor = request_tmdb_json("search/person", actor_parameter)
	actor_id = search_actor['results'][0]['id'].to_s
	actor_biography_request_url = "person/" + actor_id 
	biography = request_tmdb_json(actor_biography_request_url)['biography']
	actor_filmography_request_url = "person/" + actor_id + "/movie_credits"
	actor_filmography = request_tmdb_json(actor_filmography_request_url)
	return biography, actor_filmography
end


def request_tmdb_json(request_type_url, extra_url='')
	request_url = "http://api.themoviedb.org/3/"
	request_url += request_type_url
	request_url += "?api_key="
	request_url += TMDB_key
	request_url += extra_url

	resp = Net::HTTP.get_response(URI(request_url))
	puts JSON(resp.body)
	return JSON(resp.body)
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


def get_basic_movie_info(movie_hash, movie_id)
	basic_movie_keys = ['id', "imdb_id", 'title', 'overview', 'release_date',
						 'tagline']
	basic_info = request_tmdb_json("movie/" + movie_id.to_s)

	basic_movie_keys.each do |basic_key|
		movie_hash[basic_key] = basic_info[basic_key]	
	end
	if basic_info['poster_path'] != nil
		movie_hash['poster_path'] = "http://image.tmdb.org/t/p/w500" + basic_info['poster_path']
	end
end


def get_five_topbilled_actors(casts_request, movie_hash)
	cast_list = Array.new
	casts_request['cast'].each do |actor|
		if actor['order'] < 5 then
			cast_list.push(actor['name'])
		end
	end
	movie_hash['cast'] = cast_list.join(", ")
end


def determine_and_push_to_directors_or_screenwriters(crew, directors, screenwriters)
	if crew['job'] == "Director" then
		directors.push(crew['name'])
	elsif crew['job'] == "Screenplay" then
		screenwriters.push(crew['name'])
	end
end


def get_directors_and_screenwriters(casts_request, movie_hash)
	directors = Array.new 
	screenwriters = Array.new
	casts_request['crew'].each do |crew|
		determine_and_push_to_directors_or_screenwriters(crew, directors, screenwriters)
	end

	if directors.length > 0 then
		movie_hash['directors'] = directors.join(", ")
	end

	if screenwriters.length > 0 then
		movie_hash['screenwriters'] = screenwriters. join(", ")
	end
end


def get_casts_info(movie_hash, movie_id)
	casts_request = request_tmdb_json("movie/" + movie_id.to_s + "/casts")
	
	get_five_topbilled_actors(casts_request, movie_hash)	
	get_directors_and_screenwriters(casts_request, movie_hash)	
end


def add_trailer_or_featurette_to_moviehash(videos_json, movie_hash)
	videos_json['results'].each do |video|
		if video['type'] == "Trailer" then
			movie_hash['trailer'] = "https://www.youtube.com/watch?v=" + video['key']
		elsif video['type'] == "Featurette" then
			movie_hash['featurette'] = "https://www.youtube.com/watch?v=" + video['key']
		end
	end
end


def get_videos(movie_hash, movie_id)
	videos_json = request_tmdb_json("movie/" + movie_id.to_s + "/videos")
	if videos_json['results'].length > 0 then
		add_trailer_or_featurette_to_moviehash(videos_json, movie_hash)
	end
end


def prepare_movie_hash(movie_id)
	movie_hash = Hash.new
	get_basic_movie_info(movie_hash, movie_id)
	#search rt info using imdb_id without the prefix "tt"
	enough_movie_reviews = add_rt_info(movie_hash['imdb_id'][2..-1], movie_hash)
	if ! enough_movie_reviews then
		return nil
	end
	add_reviews_info_to_movie_hash(movie_hash, enough_movie_reviews)
	get_casts_info(movie_hash, movie_id)
	get_videos(movie_hash, movie_id)
	
	return movie_hash
end


def add_reviews_info_to_movie_hash(movie_hash, review_info)
	critics_score, audience_score, total_reviews, review_quotes = review_info
	movie_hash['critics_score'] = critics_score
	movie_hash['audience_score'] = audience_score
	movie_hash['total_reviews'] = total_reviews
	movie_hash['review_quotes'] = review_quotes
end


def search_tmdb_for_actor_and_filmography(actor_parameter)
	search_actor = request_tmdb_json("search/person", actor_parameter)
	actor_id = search_actor['results'][0]['id'].to_s
	actor_filmography_request_url = "person/" + actor_id + "/movie_credits"
	return request_tmdb_json(actor_filmography_request_url)
end


def get_json_from_rt_movie_alias(imdb_movie_id)
	request_url = "http://api.rottentomatoes.com/api/public/v1.0/"
	request_url += "movie_alias.json?apikey=" + RT_key
	request_url += "&type=imdb&id=" + imdb_movie_id

	resp = Net::HTTP.get_response(URI(request_url))
	return JSON(resp.body)
end 


def check_if_rt_scores_exist_and_return(imdb_movie_id)
	rt_json = get_json_from_rt_movie_alias(imdb_movie_id)
	begin
		critics_score = rt_json['ratings']['critics_score']
	rescue NoMethodError
		puts "No method error"
		puts imdb_movie_id
		return false
	end
	if critics_score < 0 or critics_score.nil? then
		puts "No reviews"
		puts imdb_movie_id
		return false
	end
	audience_score = rt_json['ratings']['audience_score']
	rt_movie_id = rt_json['id']
	return critics_score, audience_score, rt_movie_id
end


def check_if_six_reviews_exist(rt_movie_id)
	request_url = "http://api.rottentomatoes.com/api/public/v1.0/movies/"
	request_url += rt_movie_id.to_s + "/reviews.json?"
	request_url += "apikey=" + RT_key
	request_url += "&review_type=all"

	resp = Net::HTTP.get_response(URI(request_url))
	total_reviews = JSON(resp.body)

	if total_reviews["total"] < 6 then
		return false
	else
		return total_reviews['total'], get_review_quotes(total_reviews['reviews'])
	end

end


def get_review_quotes(reviews_json)
	quotes_list = Array.new
	reviews_json.each do |review|
		if ! review["quote"].empty?
			quotes_list.push(review["critic"] + ": " + review["quote"])
		end
	end
	return quotes_list
end


def add_rt_info(imdb_movie_id, movie_hash)
	reviews_on_rt = check_if_rt_scores_exist_and_return(imdb_movie_id)
	if ! reviews_on_rt then
		return false
	end
	critics_score, audience_score, rt_movie_id = reviews_on_rt

	enough_reviews = check_if_six_reviews_exist(rt_movie_id)
	if ! enough_reviews then
		puts "Less than six reviews"
		puts imdb_movie_id
		return false
	end
	total_reviews, review_quotes = enough_reviews
	
	return critics_score, audience_score, total_reviews, review_quotes
end


def prepare_actor_url_parameter_for_tmdb(actor_name_list)
	url_parameter = "&query=" + actor_name_list.join("+")
end


def find_and_print_tmdb_movie_info(actor_filmography, actor_db_id)
	movie_ids_list = Array.new

	actor_filmography['cast'].each do |movie_dict|
		movie_ids_list.push(movie_dict['id'])
	end

	prepare_movie_hash_and_enter_into_db(movie_ids_list, actor_db_id)
end


def prepare_movie_hash_and_enter_into_db(movie_ids_list, actor_db_id)
	movie_ids_list.each do |movie_id|
		begin
			movie_hash = prepare_movie_hash(movie_id)
			enter_movie_into_actor_db(actor_db_id, movie_hash)
		rescue SocketError, TypeError => e
			puts e.message
			next
		end
	end
end


def enter_actor_into_db(actor_name, biography)
	db = Mongo::Connection.new.db("mydb")
	coll = db.collection('actors_tmdb')
	actor_insert_id = coll.insert("actor_name" => actor_name, "biography" => biography, 
									"movies" => [])
end


def enter_movie_into_actor_db(db_id, movie_hash)
	db = Mongo::Connection.new.db("mydb")
	coll = db.collection('actors_tmdb')
	puts "We are in enter movie into actor db"
	puts movie_hash.class
	coll.update({"_id" => db_id}, {"$push" => {"movies" => movie_hash}} )
end


def pick_one_movie(db_entry_id)
	db = Mongo::Connection.new.db("mydb")
	coll = db.collection('game_sessions')

	actor_entry = coll.find_one("_id" => BSON::ObjectId(db_entry_id.to_s))
	movie_choice = actor_entry["movies"].compact.sample
	coll.update({"_id" => BSON::ObjectId(db_entry_id.to_s)}, 
				"$set" => {"critics_score" => movie_choice['critics_score']} )

	return movie_choice
end