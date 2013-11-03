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
		print('========= DENY ALL FIREWALL RULE ==========')
		local serverId = p.input:getItemUUID()
		local customerId = p.input:getCustomerUUID()
		local ipAddress = getServerIp(serverId).serverIP
		if(checkCustomerKey(customerId, "DENY_ALL_FIREWALL")) then
			local userToken = getUserToken(customerId)
			userAPI:setSessionUser(userToken)
			local firewallData = getFirewall(customerId)
			if(firewallData.success) then
				applyFireWallTemplate(ipAddress, firewallData.templateUUID)
			else
				local firewallCreateData = createFirewallTemplate(customerId)
				if(firewallCreateData.success) then
					applyFireWallTemplate(ipAddress, firewallCreateData.templateUUID)
				end
			end
		end
		print('========== DENY ALL FIREWALL RULE COMPLETE ==========')
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

function getFirewall(customerUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourcename')
	filterCondition1:setValue({"DENY_ALL_FIREWALL_TEMPLATE"})
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

function register()
	return {"firewall_deny"}
end
