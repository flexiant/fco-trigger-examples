function serverdensity_monitoring_trigger(p)
	if(p == nil) then
		return {
			ref = "serverdensity_monitoring_trigger",
			name = "ServerDensity Auto Server Monitoring",
			description = "Automaticaly add server to ServerDensity",
			priority = 0,
			triggerType = "POST_SERVER_STATE_CHANGE",
			triggerOptions = {"STOPPED"},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("======== SERVER DENSITY TRIGGER ACTIVATION =========")
	local customerUUUD = p.input:getCustomerUUID()
	local serverUUID = p.input:getResourceUUID()
	local apiToken = checkCustomerKey(customerUUUD,'SERVER_DENSITY_API_TOKEN')
	if(apiToken.success) then
		local serverKeyExists = checkServer(serverUUID)
		if(serverKeyExists.success) then
			local url = "https://api.serverdensity.io/inventory/devices/?token=" .. apiToken.keyValue
			local params = prepareParameters(p.input)
			print('Adding server : ' .. serverUUID .. ' to ServerDensity.')
			generate_http_request('',params,url)
			local userToken = getUserToken(customerUUUD)
			userAPI:setSessionUser(userToken)
			addCustomerKeyToServer(serverUUID,'1')
		else
			print('Server has allready been added to Server Density List!')
		end
	else
		print("SERVER_DENSITY_API_TOKEN key not found!")
	end
	print("======== SERVER DENSITY TRIGGER ACTIVATION COMPLETE=========")
	return { exitState = "SUCCESS" }
end

function addCustomerKeyToServer(serverUUID,customerKey)
	local resourceKey = new("ResourceKey")
	resourceKey:setName("SERVERDENSITY_ID")
	resourceKey:setValue(customerKey)
	resourceKey:setWeight(0)
	local res = userAPI:addKey(serverUUID,resourceKey)
end

function checkServer(serverUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({serverUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({'SERVERDENSITY_ID'})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local serverList = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))
	if(serverList:getList():size() == 1) then
		--returns false if server has the key
		return {success = false }
	else
		--returns true if servers doens't have the key
		return {success = true}
	end
end

function prepareParameters(server)
	local json = new("JSON")
	local params = {name = server:getResourceName() , cpuCores = server:getCpu() , group = server:getVdcName(), installedRAM = server:getRam()}
	params = json:encode(params)
	return params
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

function generate_http_request(token,params,url)
	local headers = {}
	headers['Content-Type'] = "application/json"

	local simplehttp = new("simplehttp")
	local httpconn = simplehttp:newConnection({url=url})
	httpconn:setRequestHeaders(headers)
	local returnString = ""
	local httpcode = ""
	if (httpconn:post(params,
	function (val)
		returnString = returnString .. val
		return true
	end)
	) then

	else
		local error , message = httpconn:getLastError()
		print('HTTPError: ' .. error)
		print('HTTPErrorMessage: ' .. message)
	end

	httpconn:disconnect()

	local js = new ("JSON")
	local jsonReturnString = js:decode(returnString)
end

function register()
	return {"serverdensity_monitoring_trigger"}
end