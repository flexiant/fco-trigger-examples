-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function automatic_server_shutdown_trigger(p)
	if(p == nil) then
		return {
			ref = "automatic_server_shutdown_trigger",
			name = "Automatic Server Shutdown",
			description = "Shutdowns the server after stated period of time",
			priority = 0,
			triggerType = "SCHEDULED",
			schedule={frequency={MINUTE=1}},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("======== AUTOMATIC SERVER SHUTDOWN =========")
	local serverList = getServerList()
	for i = 0, serverList.data:size() -1 ,1 do
		checkServer(serverList.data:get(i))
	end
	print("======== AUTOMATIC SERVER SHUTDOWN COMPLETE=========")
	return { exitState = "SUCCESS" }
end

function deleteServer(server)
	print("------------ delete server --------------> " .. server:getResourceUUID())
	local userToken = getUserToken(server:getCustomerUUID())
	userAPI:setSessionUser(userToken)
	print('Deleting server: ' .. server:getResourceUUID())
	userAPI:deleteResource(server:getResourceUUID(),true,nil)
end

function getServerList()
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourcekey.name')
	filterCondition1:setValue({'SHUTDOWN_AFTER'})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local servers = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))
	if(servers:getList():size() > 0) then
		return {success = true, data = servers:getList()}
	else
		return {success = false}
	end
end

function checkServer(server)
	local dateHelper = new("FDLDateHelper")
	local shutdownTimestamp = nil
	local deleteServerTime = nil
	for i = 0, server:getResourceKey():size() - 1, 1 do
		if(server:getResourceKey():get(i):getName() == 'SHUTDOWN_AFTER') then
			shutdownTimestamp = dateHelper:getTimestamp(server:getResourceCreateDate()) + tonumber(server:getResourceKey():get(i):getValue()) * 60 * 1000
			deleteServerTime = shutdownTimestamp + 7*24*60*60*1000;
		end
	end

	if(dateHelper:getTimestamp()>shutdownTimestamp) then
		shutdownServer(server)
	end

	if(dateHelper:getTimestamp() > deleteServerTime) then
		deleteServer(server)
	end
end

function shutdownServer(server)
	local userToken = getUserToken(server:getCustomerUUID())
	userAPI:setSessionUser(userToken)
	print('Shutting down server: ' .. server:getResourceUUID())
	userAPI:changeServerStatus(server:getResourceUUID(),new("ServerStatus","STOPPED"),false,nil,nil)
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

function register()
	return {"automatic_server_shutdown_trigger"}
end
