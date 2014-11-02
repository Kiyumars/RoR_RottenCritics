class HomeController < ApplicationController
  def index

  end

  def game_round
		actor_name = params["actor_name"]
		actor_name_list = actor_name.downcase.split(" ")
		actor_parameter = prepare_actor_url_parameter_for_tmdb(actor_name_list)
		bio = search_tmdb_for_actor_and_filmography(actor_parameter)
		Biography.create(:actor_name => actor_name, :biography => bio)
		@some_thing = bio
	end
end
