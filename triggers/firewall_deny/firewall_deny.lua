-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function firewall_deny(p)
	if(p == nil) then
		return {
			ref = "firewall_deny",
			name = "Deny All Firewall",
			description = "Add Deny all firewall template to all newly created servers",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"SUCCESSFUL"},
			api = "TRIGGER",
			version = 1,
		}
	end

	if(p.input:getJobType() == new("JobType","CREATE_SERVER")) then

		local serverId = p.input:getItemUUID()
		local serverImage = getServerImage(serverId)

		local imageFirewall = {success = false}

		if(serverImage.success) then
			imageFirewall = getImageFirewallName(serverImage.imageUUID)
		end

		local customerId = p.input:getCustomerUUID()
		local ipAddress = getServerIp(serverId).serverIP

		if(checkCustomerKey(customerId, "DENY_ALL_FIREWALL")) then
			print('========= DENY ALL FIREWALL RULE ==========')

			local userToken = getUserToken(customerId)
			userAPI:setSessionUser(userToken)

			local firewallData

			if(imageFirewall.success) then
				firewallData = getFirewall(customerId, imageFirewall.templateName)
			else
				firewallData = getFirewall(customerId, "DENY_ALL_FIREWALL_TEMPLATE")
			end

			if(firewallData.success) then
				applyFireWallTemplate(ipAddress, firewallData.templateUUID)
			else
				local firewallCreateData = createFirewallTemplate(customerId)
				if(firewallCreateData.success) then
					applyFireWallTemplate(ipAddress, firewallCreateData.templateUUID)
				end
			end

			print('========== DENY ALL FIREWALL RULE COMPLETE ==========')
		end

	end

	return { exitState = "SUCCESS" }
end

function getServerImage(serverId)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({serverId})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local server = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))

	if(server:getList():size() == 1 and server:getList():get(0):getImageUUID() ~= nil) then

		return {success = true, imageUUID = server:getList():get(0):getImageUUID()}
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

function createFirewallTemplate(customerUUID)
	local skeletonFirewallTemplate = new("FirewallTemplate")
	skeletonFirewallTemplate:setCustomerUUID(customerUUID)
	skeletonFirewallTemplate:setResourceName("DENY_ALL_FIREWALL_TEMPLATE")
	skeletonFirewallTemplate:setType(new("IPType","IPV4"))
	skeletonFirewallTemplate:setDefaultOutAction(new("FirewallRuleAction","REJECT"))
	skeletonFirewallTemplate:setDefaultInAction(new("FirewallRuleAction","REJECT"))
	print('Firewall template doesn\'t exist creating new Firewall template')
	local firewallCreate = userAPI:createFirewallTemplate(skeletonFirewallTemplate, nil)
	local jobQueue = userAPI:waitForJob(firewallCreate:getResourceUUID(), true)
	local response = {}
	if(jobQueue:getStatus() == new("JobStatus","SUCCESSFUL")) then
		response = {
			success = true,
			templateUUID = jobQueue:getItemUUID()
		}
	else
		response = {
			success = false
		}
	end

	return response

end

function getServerIp(serverUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({serverUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local server = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))
	if(server:getList():size() == 1) then
		local ipAddress = server:getList():get(0):getNics():get(0):getIpAddresses():get(0):getIpAddress()
		return {success = true, serverIP = ipAddress}
	else
		return {success = false}
	end
end

function applyFireWallTemplate(ipAddress,templateUUID)
	print('Applying Firewall template to : ' .. ipAddress)
	local applyTemplate = userAPI:applyFirewallTemplate(templateUUID,ipAddress,nil)
end

function getFirewall(customerUUID, firewallName)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourcename')
	filterCondition1:setValue({firewallName})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('customeruuid')
	filterCondition2:setValue({customerUUID})
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)

	local firewall = adminAPI:listResources(searchFilter,nil,new("ResourceType","FIREWALL_TEMPLATE"))
	if(firewall:getList():size() == 1) then
		return {success = true, templateUUID = firewall:getList():get(0):getResourceUUID()}
	else
		return {success = false}
	end
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
		return true
	else
		return false
	end
end

function getImageFirewallName(imageUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({imageUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({"AUTO_FIREWALL_NAME"})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local imageFirewall = adminAPI:listResources(searchFilter,nil,new("ResourceType","IMAGEINSTANCE"))

	if(imageFirewall:getList():size() == 1) then

		for j = 0, imageFirewall:getList():get(0):getResourceKey():size() - 1, 1 do
			if(imageFirewall:getList():get(0):getResourceKey():get(j):getName() == 'START_SERVER') then
				response[tonumber(imageFirewall:getList():get(0):getResourceKey():get(j):getValue())] = serverJobs:get(i):getResourceUUID()
			end
		end

		return {success = true, templateName = imageFirewall:getList():get(0):getResourceKey():get(0):getValue()}
	else
		return {success = false}
	end
end

function register()
	return {"firewall_deny"}
end
