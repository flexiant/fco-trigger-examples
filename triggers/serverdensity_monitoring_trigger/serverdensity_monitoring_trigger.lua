-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function serverdensity_monitoring_trigger(p)
	if(p == nil) then
		return {
			ref = "serverdensity_monitoring_trigger",
			name = "ServerDensity Auto Server Monitoring",
			description = "Automaticaly add server to ServerDensity",
			priority = 0,
			--triggerType = "POST_SERVER_STATE_CHANGE",
			--triggerOptions = {"RUNNING", "STOPPED"},
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"SUCCESSFUL"},
			api = "TRIGGER",
			version = 1,
		}
	end
	if(p.input:getJobType() == new("JobType","CREATE_SERVER")) then

		print("======== SERVER DENSITY TRIGGER ACTIVATION =========")
		local customerUUID = p.input:getCustomerUUID()
		local serverUUID = p.input:getItemUUID()
		local server = getServer(serverUUID)
		local apiToken = checkCustomerKey(customerUUID,'SERVER_DENSITY_API_TOKEN')

		if(apiToken.success) then
			local serverKeyExists = checkServer(serverUUID)

			if not (serverKeyExists.success) then
				local url = "https://api.serverdensity.io/inventory/devices/?token=" .. apiToken.keyValue
				local params = prepareParameters(server)
				print('Adding server : ' .. serverUUID .. ' to ServerDensity.')
				local densityApiCall = generate_http_request('',params,url)
				local userToken = getUserToken(customerUUID)
				userAPI:setSessionUser(userToken)
				addCustomerKeyToServer(serverUUID, "SERVERDENSITY_ID", densityApiCall._id)
				setAlertingOnServerDensity(apiToken.keyValue, densityApiCall._id, server)
			else
				print('Server has allready been added to Server Density List!')
			end
		else
			print("SERVER_DENSITY_API_TOKEN key not found!")
		end
		print("======== SERVER DENSITY TRIGGER ACTIVATION COMPLETE=========")
	end

	return { exitState = "SUCCESS" }
end

function setAlertingOnServerDensity(token, subjectID, server)
	print("setAlertingOnServerDensity function is called")
	local url = "https://api.serverdensity.io/alerts/configs/?token=" .. token
	local params = {
		subjectId = subjectID,
		subjectType = "device",
		enabled = false,
		section = "system",
		field = "loadAvrg",
		comparison = "gte",
		value = "0",
		recipients = {
			{
				type = "user",
				id = server:getBillingEntityUUID(),
				actions = {
					"sms",
					"email"
				}
			}
		},
		wait = {
			seconds = "60",
			enabled = true,
			displayUnits = "s"
		},
		fix = true,
	}
	params["repeat"] = {
		seconds = "300",
		enabled = true,
		displayUnits = "s"
	}
	local json = new("JSON")
	local alertParams = json:encode(params)

	local densityApiCall = generate_http_request('', alertParams, url)
	addCustomerKeyToServer(server:getResourceUUID(), "SERVERDENSITY_ALARM", densityApiCall._id)
end

function addCustomerKeyToServer(serverUUID,customerKey, customerKeyValue)
	local resourceKey = new("ResourceKey")
	resourceKey:setName(customerKey)
	resourceKey:setValue(customerKeyValue)
	resourceKey:setWeight(0)
	local res = userAPI:addKey(serverUUID,resourceKey)
end

function getServer(serverId)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({serverId})
	searchFilter:addCondition(filterCondition1)
	local serverList = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))
	return serverList:getList():get(0)
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
		for i = 0, serverList:getList():get(0):getResourceKey():size() - 1, 1 do
			if(serverList:getList():get(0):getResourceKey():get(i):getName() == "SERVERDENSITY_ID") then
				return {success = true, densityId = serverList:getList():get(0):getResourceKey():get(i):getValue() }
			end
		end
	end
	return {success = false}

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

function getAlertKey(serverUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({serverUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({'SERVERDENSITY_ALARM'})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local serverList = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))
	if(serverList:getList():size() == 1) then
		for i = 0, serverList:getList():get(0):getResourceKey():size() - 1, 1 do
			if(serverList:getList():get(0):getResourceKey():get(i):getName() == "SERVERDENSITY_ALARM") then
				return {success = true, keyValue = serverList:getList():get(0):getResourceKey():get(i):getValue() }
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
	return jsonReturnString
end

function generate_http_put_request(token,params,url)

	local simplehttp = new("simplehttp")
	local httpconn = simplehttp:newConnection({url=url})

	local returnString = ""
	local httpcode = ""

	if (httpconn:put(params,
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
	return jsonReturnString
end

function serverdensity_alerting_trigger(p)
	if(p == nil) then
		return {
			ref = "serverdensity_alerting_trigger",
			name = "ServerDensity Alerting",
			description = "Turn ON and OFF alerting system depending of server status",
			priority = 0,
			triggerType = "POST_SERVER_STATE_CHANGE",
			triggerOptions = {"RUNNING", "STOPPED"},

			api = "TRIGGER",
			version = 1,
		}
	end
	local alertIsActive
	if(p.input:getStatus() == new("ServerStatus","STOPPED")) then
		alertIsActive = "false"
	elseif(p.input:getStatus() == new("ServerStatus","RUNNING")) then
		alertIsActive = "true"
	else
		return { exitState = "SUCCESS" }
	end

	local serverUUID = p.input:getResourceUUID()
	local customerUUID = p.input:getCustomerUUID()

	local server = getServer(serverUUID)
	local apiToken = checkCustomerKey(customerUUID,'SERVER_DENSITY_API_TOKEN')
	local alertKey = getAlertKey(serverUUID)

	if(apiToken.success) then
		local serverKeyExists = checkServer(serverUUID)

		local url = "https://api.serverdensity.io/alerts/configs/" .. alertKey.keyValue .. "?token=" .. apiToken.keyValue
		local params = "enabled=" .. alertIsActive

		local densityApiCall = generate_http_put_request('', params, url)
	end

	return { exitState = "SUCCESS" }
end

function register()
	return {"serverdensity_monitoring_trigger", "serverdensity_alerting_trigger"}
end
