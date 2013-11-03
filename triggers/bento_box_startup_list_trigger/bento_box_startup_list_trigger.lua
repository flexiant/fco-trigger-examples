-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function bento_box_startup_list_trigger(p)
	if(p == nil) then
		return {
			ref = "bento_box_startup_list_trigger",
			name = "Bento Box Custom Startup Trigger",
			description = "Custom Startup for multiple servers in BentoBox",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"IN_PROGRESS"},
			api = "TRIGGER",
			version = 1,
		}
	end

	if(p.input:getItemType():toString() == "DEPLOYMENT_INSTANCE") then
		print("======== BENTOBOX CUSTOM STARTUP TRIGGER =========")
		local jobs = getChildJobs(p.input:getResourceUUID())
		if(jobs.success) then
			local servers = getServers(jobs.childJobs)
			if(table.maxn(servers) > 1) then
				for i=2, table.maxn(servers), 1 do
					print('----Job '.. i .. '- Waiting for job ' .. i-1 .. ' to finish!')
					userAPI:waitForJob(servers[i-1],true)
					print('----Job ' .. i-1 .. ' finished!----')
				end
			end
		end
		print("======== BENTOBOX CUSTOM STARTUP COMPLETE=========")
	end
	return { exitState = "SUCCESS" }

end

function getServers(serverJobs)
	local response = {}
	for i=0, serverJobs:size() - 1, 1 do
		local searchFilter = new("SearchFilter")
		local filterCondition1 = new("FilterCondition")
		filterCondition1:setField('resourceuuid')
		filterCondition1:setValue({serverJobs:get(i):getItemUUID()})
		filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
		searchFilter:addCondition(filterCondition1)
		local server = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))
		if(server:getList():size() == 1 ) then
			for j = 0, server:getList():get(0):getResourceKey():size() - 1, 1 do
				if(server:getList():get(0):getResourceKey():get(j):getName() == 'START_SERVER') then
					response[tonumber(server:getList():get(0):getResourceKey():get(j):getValue())] = serverJobs:get(i):getResourceUUID()
				end
			end
		end
	end
	return response
end

function getChildJobs(parentJobUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('parentjobuuid')
	filterCondition1:setValue({parentJobUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local job = adminAPI:listResources(searchFilter,nil,new("ResourceType","JOB"))
	local response = {}
	if(job:getList():size() > 0) then
		response = {success = true, childJobs = job:getList()}
	else
		response = {success = false}
	end
	return response
end

function register()
	return {"bento_box_startup_list_trigger"}
end