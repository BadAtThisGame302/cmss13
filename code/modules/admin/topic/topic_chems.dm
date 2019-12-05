/datum/admins/proc/topic_chems(var/href)
	switch(href)
		if("view_reagent")
			var/target = input(usr,"Enter the ID of the chemical reagent you wish to view:")
			if(!target)
				return
			var/datum/reagent/R = chemical_reagents_list[target]
			if(R)
				usr.client.debug_variables(R)
			else
				to_chat(usr,SPAN_WARNING("No reagent with this ID could been found."))
			return
		if("view_reaction")
			var/target = input(usr,"Enter the ID of the chemical reaction you wish to view:")
			if(!target)
				return
			var/datum/chemical_reaction/R = chemical_reactions_list[target]
			if(R)
				usr.client.debug_variables(R)
				log_admin("[key_name(usr)] is viewing the chemical reaction for [R].")
			else
				to_chat(usr,SPAN_WARNING("No reaction with this ID could been found."))
			return
		if("spawn_reagent")
			var/target = input(usr,"Enter the ID of the chemical reagent you wish to make:")
			if(!target)
				return
			if(!chemical_reagents_list[target])
				to_chat(usr,SPAN_WARNING("No reagent with this ID could been found."))
				return
			var/volume = input(usr,"How much? An appropriate container will be selected.") as num
			if(volume <= 0)
				return
				
			if(volume > 120)
				if(volume > 300)
					volume = 300
				var/obj/item/reagent_container/glass/beaker/bluespace/C = new /obj/item/reagent_container/glass/beaker/bluespace(usr.loc)
				C.reagents.add_reagent(target,volume)
			else if (volume > 60)
				var/obj/item/reagent_container/glass/beaker/large/C = new /obj/item/reagent_container/glass/beaker/large(usr.loc)
				C.reagents.add_reagent(target,volume)
			else if (volume > 30)
				var/obj/item/reagent_container/glass/beaker/C = new /obj/item/reagent_container/glass/beaker(usr.loc)
				C.reagents.add_reagent(target,volume)
			else
				var/obj/item/reagent_container/glass/beaker/vial/C = new /obj/item/reagent_container/glass/beaker/vial(usr.loc)
				C.reagents.add_reagent(target,volume)
			return
		//For quickly generating a new chemical
		if("create_random_reagent")
			var/target = input(usr,"Enter the ID of the chemical reagent you wish to make:")
			if(!target)
				return
			if(chemical_reagents_list[target])
				to_chat(usr,SPAN_WARNING("This ID is already in use."))
				return
			var/tier = input(usr,"Enter the generation tier you wish. This will affect the number of properties (tier + 1), rarity of components and potential for good properties. Ought to be 1-4, max 10.") as num
			if(tier <= 0)
				return

			if(tier > 10) 
				tier = 10
			var/datum/reagent/generated/R = new /datum/reagent/generated
			var/list/stats_holder = list("name","properties","description","overdose","overdose_critical","nutriment_factor","custom_metabolism","color")
			chemical_gen_stats_list["[target]"] += stats_holder
			R.id = target
			R.gen_tier = tier
			R.chemclass = CHEM_CLASS_NONE //So we don't count it towards defcon
			R.properties = list()
			R.generate_name()
			R.generate_stats()
			//Save all variables from our holder
			R.name = chemical_gen_stats_list["[target]"]["name"]
			R.properties = chemical_gen_stats_list["[target]"]["properties"]
			R.description = chemical_gen_stats_list["[target]"]["description"]
			R.overdose = chemical_gen_stats_list["[target]"]["overdose"]
			R.overdose_critical = chemical_gen_stats_list["[target]"]["overdose_critical"]
			R.nutriment_factor = chemical_gen_stats_list["[target]"]["nutriment_factor"]
			R.custom_metabolism = chemical_gen_stats_list["[target]"]["custom_metabolism"]
			R.color = chemical_gen_stats_list["[target]"]["color"]
			//Save our reagent
			chemical_reagents_list[target] = R
			log_admin("[key_name(usr)] has generated the reagent: [target].")
			message_admins("[key_name_admin(usr)] has generated the reagent: [target].")
			var/response = alert(usr,"Do you want to do anything else?",null,"Generate associated reaction","View my reagent","Finish")
			while(response != "Finish")
				switch(response)
					if("Generate associated reaction")
						if(chemical_reactions_list[target])
							to_chat(usr,SPAN_WARNING("This ID is already in use."))
							return
						var/datum/chemical_reaction/generated/G = new /datum/chemical_reaction/generated
						var/list/recipe_holder = list("required_reagents","required_catalysts")
						chemical_gen_reactions_list["[target]"] += recipe_holder
						G.id = target
						G.result = target
						G.name = R.name
						G.gen_tier = tier
						G.generate_recipe()
						//Save all variables from our holder
						G.required_reagents = chemical_gen_reactions_list["[target]"]["required_reagents"]
						G.required_catalysts = chemical_gen_reactions_list["[target]"]["required_catalysts"]
						//Save our reaction
						chemical_reactions_list[target] = G
						if(!chemical_reactions_list[target])
							to_chat(usr,SPAN_WARNING("Something went wrong when saving the reaction."))
							chemical_gen_stats_list["[target]"] -= stats_holder
							return
						var/list/reaction_ids = list()
						if(G.required_reagents && G.required_reagents.len)
							for(var/reaction in G.required_reagents)
								reaction_ids += reaction
						// Create filters based on each reagent id in the required reagents list
						for(var/id in reaction_ids)
							if(!chemical_reactions_filtered_list[id])
								chemical_reactions_filtered_list[id] = list()
							chemical_reactions_filtered_list[id] += G
							break // Don't bother adding ourselves to other reagent ids, it is redundant.
						response = alert(usr,"Do you want to do anything else?",null,"View my reaction","View my reagent","Finish")
					if("View my reagent")
						if(chemical_reagents_list[target])
							R = chemical_reagents_list[target]
							usr.client.debug_variables(R)
							log_admin("[key_name(usr)] is viewing the chemical reaction for [R].")
						else
							to_chat(usr,SPAN_WARNING("No reaction with this ID could been found. Wait what? But I just... Contact a debugger."))
							chemical_gen_stats_list.Remove("[target]")
							chemical_gen_reactions_list.Remove("[target]")
						return
					if("View my reaction")
						if(chemical_reactions_list[target])
							var/datum/chemical_reaction/generated/G = chemical_reactions_list[target]
							usr.client.debug_variables(G)
						else
							to_chat(usr,SPAN_WARNING("No reaction with this ID could been found. Wait what? But I just... Contact a debugger."))
							chemical_gen_stats_list.Remove("[target]")
							chemical_gen_reactions_list.Remove("[target]")
						return
					else
						break
			//See what we want to do last
			if(alert(usr,"Spawn container with reagent?","Custom reagent [target]","Yes","No") == "No")
				return

			var/volume = input(usr,"How much? An appropriate container will be selected.") as num
			if(volume <= 0)
				return
			if(volume > 120)
				if(volume > 300)
					volume = 300
				var/obj/item/reagent_container/glass/beaker/bluespace/C = new /obj/item/reagent_container/glass/beaker/bluespace(usr.loc)
				C.reagents.add_reagent(target,volume)
			else if (volume > 60)
				var/obj/item/reagent_container/glass/beaker/large/C = new /obj/item/reagent_container/glass/beaker/large(usr.loc)
				C.reagents.add_reagent(target,volume)
			else if (volume > 30)
				var/obj/item/reagent_container/glass/beaker/C = new /obj/item/reagent_container/glass/beaker(usr.loc)
				C.reagents.add_reagent(target,volume)
			else
				var/obj/item/reagent_container/glass/beaker/vial/C = new /obj/item/reagent_container/glass/beaker/vial(usr.loc)
				C.reagents.add_reagent(target,volume)
			return
		//For creating a custom reagent
		if("create_custom_reagent")
			var/target = input(usr,"Enter the ID of the chemical reagent you wish to make:")
			if(!target)
				return
			if(chemical_reagents_list[target])
				to_chat(usr,SPAN_WARNING("This ID is already in use."))
				return
			var/datum/reagent/generated/R = new /datum/reagent/generated
			var/list/stats_holder = list("name" = target,"properties" = list(),"description" = "","overdose" = 15,"overdose_critical" = 30,"nutriment_factor" = 0,"custom_metabolism" = 0.2,"color" = text("#[][][]",num2hex(rand(0,255)),num2hex(rand(0,255)),num2hex(rand(0,255))))
			chemical_gen_stats_list["[target]"] += stats_holder
			R.id = target
			R.chemclass = CHEM_CLASS_NONE //So we don't count it towards defcon
			R.properties = list()
			var/response = alert(usr,"Use capitalized ID as name?","Custom reagent [target]","[capitalize(target)]","Random name")
			if(!response)
				return
			if(response == "Random name")
				R.generate_name()
			else
				chemical_gen_stats_list["[target]"]["name"] = capitalize(response)
			response = alert(usr,"What do you want customized?","Custom reagent [target]","Add property","Randomize non property vars","Finish")
			while(response != "Finish")
				switch(response)
					if("Add property")
						response = alert(usr,"A specific property or a specific number of random properties?","Custom reagent [target]","Specific property","Specific number","No more properties")
					if("Specific property")
						var/property_type = alert(usr,"What kind?","Custom reagent [target]","Negative","Neutral","Positive")
						var/list/pool
						switch(property_type)
							if("Negative")
								pool = get_negative_chem_properties(1)
							if("Neutral")
								pool = get_neutral_chem_properties(1)
							if("Positive")
								pool = get_positive_chem_properties(1)
							else
								response = alert(usr,"No? Then..","Custom reagent [target]","Specific property","Specific number","No more properties")
						pool = sortAssoc(pool)
						var/property = input(usr,"Which property do you want?") as null|anything in pool
						var/potency = input(usr,"Choose the potency (this is a strength modifier, ought to be between 1-4)") as num
						R.add_property(property,potency)
						response = alert(usr,"Done. Add more?","Custom reagent [target]","Specific property","Specific number","No more properties")
					if("Specific number")
						var/number = input(usr,"How many properties?") as num
						R.gen_tier = input(usr,"Enter the generation tier. This will affect how potent the properties can be. Must be between 1-4.") as num
						if(number > 10) number = 10
						for(var/i=1,i<=number,i++)
							R.add_property()
						response = alert(usr,"Done. What do you want customized next?","Custom reagent [target]","Add property","Randomize non property vars","Finish")
					if("No more properties")
						response = alert(usr,"What do you want customized?","Custom reagent [target]","Add property","Randomize non property vars","Finish")
					if("Randomize non property vars")
						R.generate_stats(1)
						response = alert(usr,"Done. What do you want customized next?","Custom reagent [target]","Add property","Randomize non property vars","Finish")
					else
						break
			//Save all variables from our holder
			R.name = chemical_gen_stats_list["[target]"]["name"]
			R.properties = chemical_gen_stats_list["[target]"]["properties"]
			R.description = chemical_gen_stats_list["[target]"]["description"]
			R.overdose = chemical_gen_stats_list["[target]"]["overdose"]
			R.overdose_critical = chemical_gen_stats_list["[target]"]["overdose_critical"]
			R.nutriment_factor = chemical_gen_stats_list["[target]"]["nutriment_factor"]
			R.custom_metabolism = chemical_gen_stats_list["[target]"]["custom_metabolism"]
			R.color = chemical_gen_stats_list["[target]"]["color"]
			//Save our reagent
			chemical_reagents_list[target] = R
			log_admin("[key_name(usr)] has created a custom reagent: [target].")
			message_admins("[key_name_admin(usr)] has created a custom reagent: [target].")
			//See what we want to do last
			response = alert(usr,"Spawn container with reagent?","Custom reagent [target]","Yes","No, show me the reagent","No, I'm all done")
			switch(response)
				if("Yes")
					var/volume = input(usr,"How much? An appropriate container will be selected.") as num
					if(volume <= 0)
						return
					if(volume > 120)
						if(volume > 300)
							volume = 300
						var/obj/item/reagent_container/glass/beaker/bluespace/C = new /obj/item/reagent_container/glass/beaker/bluespace(usr.loc)
						C.reagents.add_reagent(R.id,volume)
					else if (volume > 60)
						var/obj/item/reagent_container/glass/beaker/large/C = new /obj/item/reagent_container/glass/beaker/large(usr.loc)
						C.reagents.add_reagent(R.id,volume)
					else if (volume > 30)
						var/obj/item/reagent_container/glass/beaker/C = new /obj/item/reagent_container/glass/beaker(usr.loc)
						C.reagents.add_reagent(R.id,volume)
					else
						var/obj/item/reagent_container/glass/beaker/vial/C = new /obj/item/reagent_container/glass/beaker/vial(usr.loc)
						C.reagents.add_reagent(R.id,volume)
				if("No, show me the reagent")
					usr.client.debug_variables(chemical_reagents_list[target])
			return
		//For creating a custom reaction
		if("create_custom_reaction")
			var/target = input(usr,"Enter the ID of the chemical reaction you wish to make:")
			if(!target)
				return
			if(chemical_reactions_list[target])
				to_chat(usr,SPAN_WARNING("This ID is already in use."))
				return
			var/datum/chemical_reaction/generated/R = new /datum/chemical_reaction/generated
			var/list/recipe_holder = list("required_reagents","required_catalysts","result")
			chemical_gen_reactions_list["[target]"] += recipe_holder
			R.id = target
			chemical_gen_reactions_list["[target]"]["result"] = input(usr,"Enter the reagent ID the reaction should result in:")
			R.name = capitalize(target)
			var/modifier = 1
			var/component = "water"
			var/catalyst = FALSE
			var/response = alert(usr,"What do you want customized?","Custom reaction [target]","Add component","Add catalyst","Finish")
			while(response != "Finish")
				switch(response)
					if("Add component")
						catalyst = FALSE
						response = "Select type"
					if("Add catalyst")
						catalyst = TRUE
						response = "Select type"
					if("Select type")
						response = alert(usr,"Enter id manually or select from list?","Custom reaction [target]","Select from list","Manual input","Back")
					if("Select from list")
						var/list/pool = chemical_reagents_list
						//for(var/datum/reagent/I in chemical_reagents_list)
							//pool += I.id
						pool = sortAssoc(pool)
						component = input(usr,"Select:") as null|anything in pool
						if(!component)
							response = "Select type"
							continue
						response = "Add"
					if("Manual input")
						component = input(usr,"Enter the ID of the reagent:")
						if(!component)
							response = "Select type"
							continue
						if(!chemical_reagents_list[component])
							to_chat(usr,SPAN_WARNING("ID not found. Try again."))
							continue
						response = "Add"
					if("Add")
						modifier = input("How much is required per reaction?") as num
						R.add_component(component,modifier,catalyst)
						response = "Back"
					if("Back")
						response = alert(usr,"What do you want customized?","Custom reaction [target]","Add component","Add catalyst","Finish")
					else
						return
			//Save all variables from our holder
			R.required_reagents = chemical_gen_reactions_list["[target]"]["required_reagents"]
			R.required_catalysts = chemical_gen_reactions_list["[target]"]["required_catalysts"]
			R.result = chemical_gen_reactions_list["[target]"]["result"]
			//Save each reaction ID
			var/list/reaction_ids = list()
			if(R.required_reagents && R.required_reagents.len)
				for(var/reaction in R.required_reagents)
					reaction_ids += reaction
			if(reaction_ids && reaction_ids.len < 3)
				to_chat(usr,SPAN_WARNING("You need to add at least 3 components."))
				return
			//Save our reaction
			chemical_reactions_list[target] = R
			if(!chemical_reactions_list[target])
				to_chat(usr,SPAN_WARNING("Something went wrong when saving the reaction."))
				return
			// Create filters based on each reagent id in the required reagents list
			for(var/id in reaction_ids)
				if(!chemical_reactions_filtered_list[id])
					chemical_reactions_filtered_list[id] = list()
				chemical_reactions_filtered_list[id] += R
				break // Don't bother adding ourselves to other reagent ids, it is redundant.
			usr.client.debug_variables(chemical_reactions_list[target])
			log_admin("[key_name(usr)] has created a custom chemical reaction: [target].")
			message_admins("[key_name_admin(usr)] has created a custom chemical reaction: [target].")
			return