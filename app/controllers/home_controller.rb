class HomeController < ApplicationController
  def index

  end

  def start_round
		actor_name = params["actor_name"]
		@players = params["players"].split(",").map(&:strip)

		actor_in_db = check_if_actor_in_db(actor_name)
		if ! actor_in_db then
			actor_name_list = actor_name.downcase.split
			actor_parameter = prepare_actor_url_parameter_for_tmdb(actor_name_list)
			biography, filmography = search_tmdb_for_actor_and_return_filmography(actor_parameter)
			actor_db_id = enter_actor_into_db(actor_name, biography)
			find_and_print_tmdb_movie_info(filmography, actor_db_id)
			@game_id = start_game_session(@players, actor_db_id)
			@movie = pick_one_movie(@game_id)
		elsif actor_in_db.count > 0 then
			@game_id = start_game_session(@players, actor_in_db['_id'])
			@movie = pick_one_movie(@game_id)
		end
	end
end
