function auto_server_failover(p)
	if(p == nil) then
		return {
			ref = "auto_server_failover",
			name = "Automatic Server Failover",
			description = "Starts a backup server when a live server is shutdown or killed",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"SUCCESSFUL"},
			api = "TRIGGER",
			version = 1,
		}
	end
	local jobType = p.input:getJobType():toString()

	if(jobType == "KILL_SERVER")or (jobType == "SHUTDOWN_SERVER") then
		local customerUUID = p.input:getCustomerUUID()
		local customerCheck = checkCustomerKey(customerUUID, "AUTO_FAILOVER")

		if(customerCheck.success) then
			local resourceKey = new("ResourceKey")
			resourceKey:setName("LIVE_SERVER")
			adminAPI:removeKey(p.input:getItemUUID(),resourceKey)
			serverStatus = p.input:getItemUUID()
			print("======== AUTOMATIC SERVER STARTUP =========")
			local serverList = getServerList()
			for i = 0, serverList.data:size() -1 ,1 do
				checkServer(serverList.data:get(i))
			end
			print("======== AUTOMATIC SERVER STARTUP COMPLETE=========")
			return { exitState = "SUCCESS" }
		else
			print("Customer key not set.")
		end
	end
end

function getServerList()
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourcekey.name')
	filterCondition1:setValue({'BACKUP_SERVER'})
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
	local startTimestamp = nil
	for i = 0, server:getResourceKey():size() - server:getResourceKey():size()+1, 1 do
		if(server:getResourceKey():get(i):getName() == 'BACKUP_SERVER') then

			startbackupServer(server)
		end
	end
end

function startbackupServer(server)
	local resourceKey = new("ResourceKey")
	resourceKey:setName("LIVE_SERVER")
	resourceKey:setValue(1)
	resourceKey:setWeight(0)
	local resourceKey1 = new("ResourceKey")
	resourceKey1:setName("BACKUP_SERVER")
	local userToken = getUserToken(server:getCustomerUUID())
	userAPI:setSessionUser(userToken)
	print('Starting backup server: ' .. server:getResourceUUID())
	userAPI:addKey(server:getResourceUUID(),resourceKey)
	adminAPI:removeKey(server:getResourceUUID(),resourceKey1) -- userAPI?
	userAPI:changeServerStatus(server:getResourceUUID(),new("ServerStatus","RUNNING"),false,nil,nil)
	local resourceKey2 = new("ResourceKey")
	resourceKey2:setName("BACKUP_SERVER")
	resourceKey2:setValue(1)
	resourceKey2:setWeight(0)
	adminAPI:addKey(serverStatus,resourceKey2)
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
	return {"auto_server_failover"}
end
