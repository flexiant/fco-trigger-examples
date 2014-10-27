function pre_set_unit_warning_level(p)
	if(p == nil) then
		return {
			ref = "pre_set_unit_warning_level",
			name = "Pre Set Unit Warning Level",
			description = "This trigger will set the warning level when a customer signs up",
			priority = 0,
			triggerType = "PRE_CREATE",
			triggerOptions = {"CUSTOMER"},
			api = "TRIGGER",
			version = 1,
		}
	end
	print("========== CALLED ==========")
	local warningkey = checkBeKey(p.beUUID, 'SIGNUP_WARNING_SET') --Set BE key value
	if(warningkey.success) then

		print("========== START SETTING WARNING LEVEL ==========")
		p.input:setWarningLevel(500) --change warning level value(Only a double will be accepeted)
		print("========== COMPLETE SETTING WARNING LEVEL==========")
	end
	return { exitState = "SUCCESS" }
end

function checkBeKey(beUUID, resourceKeyName)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({beUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({resourceKeyName})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local billingEntity = adminAPI:listResources(searchFilter,nil,new("ResourceType","BILLING_ENTITY"))
	if(billingEntity:getList():size() == 1) then
		for i = 0, billingEntity:getList():get(0):getResourceKey():size() - 1, 1 do
			if(billingEntity:getList():get(0):getResourceKey():get(i):getName() == resourceKeyName) then
				return {success = true, keyValue = billingEntity:getList():get(0):getResourceKey():get(i):getValue() }
			end
		end
	else
		return {success = false}
	end
end

function register()
	return {
		"pre_set_unit_warning_level",
	}
end
