-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function auto_start_server(p)
	if(p == nil) then
		return {
			ref = "auto_start_server",
			name = "Auto Start Server",
			description = "Automatically start newly created servers if customer has AUTO_START_SERVERS Customer Key Set to 'yes'",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"SUCCESSFUL"},
			api = "TRIGGER",
			version = 1,
		}
	end
	
	if(p.input:getJobType() == new("JobType","CREATE_SERVER")) then
		print('========== AUTO START SERVER TRIGGER ==========')
		local serverId = p.input:getItemUUID()
		local customerUUID = p.input:getCustomerUUID()
		local customerCheck = checkCustomerKey(customerUUID, "AUTO_START_SERVERS")
		if(customerCheck.success) then
			local userToken = getUserToken(customerUUID)
			userAPI:setSessionUser(userToken)
			print('Starting up server: ' .. serverId)
			local startServer = userAPI:changeServerStatus(serverId, new("ServerStatus","RUNNING"), true, nil, nil)
		else
			print("Customer key not set.")
		end
		print('========== AUTO START SERVER TRIGGER COMPLETE ==========')
	end

	return { exitState = "SUCCESS" }
end

function getUserToken(customerUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({customerUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local customer = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))

	local userEmail = customer:getList():get(0):getUsers():get(0):getEmail()

	return userEmail .. "/" .. customer:getList():get(0):getResourceUUID()
end

function checkCustomerKey(customerUUID, resourceKeyName)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({customerUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({resourceKeyName})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local customer = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))
	if(customer:getList():size() == 1) then
		for i = 0, customer:getList():get(0):getResourceKey():size() - 1, 1 do
			if(customer:getList():get(0):getResourceKey():get(i):getName() == resourceKeyName) then
				return {success = true, keyValue = customer:getList():get(0):getResourceKey():get(i):getValue() }
			end
		end
	else
		return {success = false}
	end
end

function register()
	return {"auto_start_server"}
end