//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:31

/*
 * GAMEMODES (by Rastaf0)
 *
 * In the new mode system all special roles are fully supported.
 * You can have proper wizards/traitors/changelings/cultists during any mode.
 * Only two things really depends on gamemode:
 * 1. Starting roles, equipment and preparations
 * 2. Conditions of finishing the round.
 *
 */

var/global/datum/entity/round_stats/round_statistics
var/global/list/datum/entity/player_entity/player_entities = list()

/datum/game_mode
	var/name = "invalid"
	var/config_tag = null
	var/intercept_hacked = 0
	var/votable = 1
	var/probability = 0
	var/list/datum/mind/modePlayer = new
	var/list/restricted_jobs = list()	// Jobs it doesn't make sense to be.  I.E chaplain or AI cultist
	var/list/protected_jobs = list()	// Jobs that can't be traitors because
	var/required_players = 0
	var/required_players_secret = 0 //Minimum number of players for that game mode to be chose in Secret
	var/newscaster_announcements = null
	var/ert_disabled = 0
	var/uplink_welcome = "Syndicate Uplink Console:"
	var/uplink_uses = 10
	var/force_end_at = 0
	var/xeno_evo_speed = 0 // if not 0 - gives xeno an evo boost/nerf
	var/is_in_endgame = FALSE //Set it to TRUE when we trigger DELTA alert or dropship crashes
	var/list/datum/mind/traitors = list()
	var/obj/structure/machinery/computer/shuttle_control/active_lz = null

	var/datum/entity/round_stats/round_stats = null

	var/scheduler_logging_current_interval = MINUTES_30//30 minutes in
	var/scheduler_logging_ongoing_interval = MINUTES_30//every 30 minutes

/datum/game_mode/proc/announce() //to be calles when round starts
	to_world("<B>Notice</B>: [src] did not define announce()")

///can_start()
///Checks to see if the game can be setup and ran with the current number of players or whatnot.
/datum/game_mode/proc/can_start()
	var/playerC = 0
	for(var/mob/new_player/player in player_list)
		if((player.client)&&(player.ready))
			playerC++

	if(master_mode=="secret")
		if(playerC >= required_players_secret)
			return 1
	else
		if(playerC >= required_players)
			return 1
	return 0


///pre_setup()
///Attempts to select players for special roles the mode might have.
/datum/game_mode/proc/pre_setup()
	setup_round_stats()
	return 1


///post_setup()
///Everyone should now be on the station and have their normal gear.  This is the place to give the special roles extra things
/datum/game_mode/proc/post_setup()
	spawn (ROUNDSTART_LOGOUT_REPORT_TIME)
		display_roundstart_logout_report()

	for(var/mob/new_player/np in player_list)
		np.new_player_panel_proc()
	feedback_set_details("round_start","[time2text(world.realtime)]")
	if(ticker && ticker.mode)
		feedback_set_details("game_mode","[ticker.mode]")
	feedback_set_details("server_ip","[world.internet_address]:[world.port]")
	return 1


///process()
///Called by the gameticker
/datum/game_mode/proc/process()
	return 0


/datum/game_mode/proc/check_finished() //to be called by ticker
	if(EvacuationAuthority.dest_status == NUKE_EXPLOSION_FINISHED || EvacuationAuthority.dest_status == NUKE_EXPLOSION_GROUND_FINISHED ) r_TRU

/datum/game_mode/proc/cleanup()	//This is called when the round has ended but not the game, if any cleanup would be necessary in that case.
	return

/datum/game_mode/proc/announce_ending()
	if(round_statistics)
		round_statistics.track_round_end()
	to_world("<span class='round_header'>|Round Complete|</span>")
	feedback_set_details("round_end_result",round_finished)

	to_world("<span class='round_body'>Thus ends the story of the brave men and women of the [MAIN_SHIP_NAME] and their struggle on [map_tag].</span>")
	to_world("<span class='round_body'>The game-mode was: [master_mode]!</span>")
	to_world("<span class='round_body'>End of Round Grief (EORG) is an IMMEDIATE 3 hour ban with no warnings, see rule #3 for more details.</span>")


/datum/game_mode/proc/declare_completion()
	if(round_statistics)
		round_statistics.track_round_end()
	var/clients = 0
	var/surviving_humans = 0
	var/surviving_total = 0
	var/ghosts = 0

	for(var/mob/M in player_list)
		if(M.client)
			clients++
			if(ishuman(M))
				if(!M.stat)
					surviving_humans++
			if(!M.stat)
				surviving_total++

			if(isobserver(M))
				ghosts++

	if(clients > 0)
		feedback_set("round_end_clients",clients)
	if(ghosts > 0)
		feedback_set("round_end_ghosts",ghosts)
	if(surviving_humans > 0)
		feedback_set("survived_human",surviving_humans)
	if(surviving_total > 0)
		feedback_set("survived_total",surviving_total)

	//send2mainirc("A round of [src.name] has ended - [surviving_total] survivors, [ghosts] ghosts.")

	return 0

/datum/game_mode/proc/calculate_end_statistics()
	for(var/mob/M in living_mob_list)
		M.track_death_calculations()
		M.statistic_exempt = TRUE

/datum/game_mode/proc/show_end_statistics()
	round_statistics.update_panel_data()
	for(var/mob/M in player_list)
		if(M.client && M.client.player_entity)
			M.client.player_entity.show_statistics(M, round_statistics, TRUE)
	save_player_entities()

/datum/game_mode/proc/check_win() //universal trigger to be called at mob death, nuke explosion, etc. To be called from everywhere.
	return 0

/datum/game_mode/proc/get_players_for_role(var/role, override_jobbans = 0)
	var/list/players = list()
	var/list/candidates = list()

	var/roletext
	switch(role)
		if(BE_ALIEN)				roletext = "Alien"
		if(BE_QUEEN)				roletext = "Queen"
		if(BE_SURVIVOR)				roletext = "Survivor"
		if(BE_PREDATOR)				roletext = "Predator"
		if(BE_SYNTH_SURVIVOR)		roletext = "Synth Survivor"

	//Assemble a list of active players without jobbans.
	for(var/mob/new_player/player in player_list)
		if(player.client && player.ready)
			if(!jobban_isbanned(player, roletext))
				players += player

	//Shuffle the players list so that it becomes ping-independent.
	players = shuffle(players)

	//Get a list of all the people who want to be the antagonist for this round
	for(var/mob/new_player/player in players)
		if(player.client.prefs.be_special & role)
			log_debug("[player.key] had [roletext] enabled, so we are drafting them.")
			candidates += player.mind
			players -= player

	//Remove candidates who want to be antagonist but have a job that precludes it
	if(restricted_jobs)
		for(var/datum/mind/player in candidates)
			for(var/job in restricted_jobs)
				if(player.assigned_role == job)
					candidates -= player

	return candidates		//Returns:	The number of people who had the antagonist role set to yes


/datum/game_mode/proc/latespawn(var/mob)

/datum/game_mode/proc/num_players()
	. = 0
	for(var/mob/new_player/P in player_list)
		if(P.client && P.ready)
			. ++


///////////////////////////////////
//Keeps track of all living heads//
///////////////////////////////////
/datum/game_mode/proc/get_living_heads()
	var/list/heads = list()
	for(var/mob/living/carbon/human/player in living_human_list)
		if(player.stat!=2 && player.mind && (player.mind.assigned_role in ROLES_COMMAND ))
			heads += player.mind
	return heads


////////////////////////////
//Keeps track of all heads//
////////////////////////////
/datum/game_mode/proc/get_all_heads()
	var/list/heads = list()
	for(var/mob/player in mob_list)
		if(player.mind && (player.mind.assigned_role in ROLES_COMMAND ))
			heads += player.mind
	return heads

/datum/game_mode/proc/check_antagonists_topic(href, href_list[])
	return 0

/datum/game_mode/New()
	if(!map_tag)
		to_world("MT001: No mapping tag set, tell a coder. [map_tag]")

//////////////////////////
//Reports player logouts//
//////////////////////////
proc/display_roundstart_logout_report()
	var/msg = SPAN_NOTICE("<b>Roundstart logout report\n\n")
	for(var/mob/living/L in mob_list)

		if(L.ckey)
			var/found = 0
			for(var/client/C in clients)
				if(C.ckey == L.ckey)
					found = 1
					break
			if(!found)
				msg += "<b>[L.name]</b> ([L.ckey]), the [L.job] (<font color='#ffcc00'><b>Disconnected</b></font>)\n"


		if(L.ckey && L.client)
			if(L.client.inactivity >= (ROUNDSTART_LOGOUT_REPORT_TIME / 2))	//Connected, but inactive (alt+tabbed or something)
				msg += "<b>[L.name]</b> ([L.ckey]), the [L.job] (<font color='#ffcc00'><b>Connected, Inactive</b></font>)\n"
				continue //AFK client
			if(L.stat)
				if(L.stat == UNCONSCIOUS)
					msg += "<b>[L.name]</b> ([L.ckey]), the [L.job] (Dying)\n"
					continue //Unconscious
				if(L.stat == DEAD)
					msg += "<b>[L.name]</b> ([L.ckey]), the [L.job] (Dead)\n"
					continue //Dead

			continue //Happy connected client
		for(var/mob/dead/observer/D in mob_list)
			if(D.mind && (D.mind.original == L || D.mind.current == L))
				if(L.stat == DEAD)
					msg += "<b>[L.name]</b> ([ckey(D.mind.key)]), the [L.job] (Dead)\n"
					continue //Dead mob, ghost abandoned
				else
					if(D.can_reenter_corpse)
						msg += "<b>[L.name]</b> ([ckey(D.mind.key)]), the [L.job] (<font color='red'><b>This shouldn't appear.</b></font>)\n"
						continue //Lolwhat
					else
						msg += "<b>[L.name]</b> ([ckey(D.mind.key)]), the [L.job] (<font color='red'><b>Ghosted</b></font>)\n"
						continue //Ghosted while alive

	for(var/mob/M in mob_list)
		if(M.client && M.client.admin_holder && (M.client.admin_holder.rights & R_MOD))
			to_chat(M, msg)


proc/get_nt_opposed()
	var/list/dudes = list()
	for(var/mob/living/carbon/human/man in player_list)
		if(man.client)
			if(man.client.prefs.nanotrasen_relation == "Opposed")
				dudes += man
			else if(man.client.prefs.nanotrasen_relation == "Skeptical" && prob(50))
				dudes += man
	if(dudes.len == 0) return null
	return pick(dudes)

//Announces objectives/generic antag text.
/proc/show_generic_antag_text(var/datum/mind/player)
	if(player.current)
		player.current << \
		"You are an antagonist! <font color=blue>Within the rules,</font> \
		try to act as an opposing force to the crew. Further RP and try to make sure \
		other players have <i>fun</i>! If you are confused or at a loss, always adminhelp, \
		and before taking extreme actions, please try to also contact the administration! \
		Think through your actions and make the roleplay immersive! <b>Please remember all \
		rules aside from those without explicit exceptions apply to antagonists.</b>"

/proc/show_objectives(var/datum/mind/player)

	if(!player || !player.current) return

	if(config.objectives_disabled)
		show_generic_antag_text(player)
		return

	var/obj_count = 1
	to_chat(player.current, SPAN_NOTICE(" Your current objectives:"))
	for(var/datum/objective/objective in player.objectives)
		to_chat(player.current, "<B>Objective #[obj_count]</B>: [objective.explanation_text]")
		obj_count++

/datum/game_mode/proc/printplayer(var/datum/mind/ply)
	if(!ply) return
	var/role

	if(ply.special_role)
		role = ply.special_role
	else
		role = ply.assigned_role

	var/text = "<br><b>[ply.name]</b>(<b>[ply.key]</b>) as \a <b>[role]</b> ("
	if(ply.current)
		if(ply.current.stat == DEAD)
			text += "died"
		else
			text += "survived"
		if(ply.current.real_name != ply.name)
			text += " as <b>[ply.current.real_name]</b>"
	else
		text += "body destroyed"
	text += ")"

	return text

/datum/game_mode/proc/setup_round_stats()
	if(!round_stats)
		var/operation_name
		operation_name = "[pick(operation_titles)]"
		operation_name += " [pick(operation_prefixes)]"
		operation_name += "-[pick(operation_postfixes)]"
		round_stats = new()
		round_stats.name = operation_name
		round_stats.real_time_start = world.realtime
		var/datum/entity/map_stats/new_map = new()
		new_map.name = map_tag
		new_map.linked_round = round_stats
		new_map.death_stats_list = round_stats.death_stats_list
		round_stats.game_mode = name
		round_stats.current_map = new_map
		round_statistics = round_stats