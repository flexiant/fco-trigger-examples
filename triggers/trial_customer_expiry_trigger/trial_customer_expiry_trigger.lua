-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function trial_customer_expiry_trigger(p)
	if(p == nil) then
		return {
			ref = "trial_customer_expiry_trigger",
			name = "Trial customer expiry trigger",
			description = "Automatic customer and server trial expiry trigger",
			priority = 0,
			triggerType = "SCHEDULED",
			schedule={frequency={HOUR=1}},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("======== AUTOMATIC TRIAL CHECKER =========")
	
	local trialCustomerList = getCustomersWithKey("TRIAL")
	
	print("======== AUTOMATIC TRIAL CHECKER COMPLETE=========")
	
	return { exitState = "SUCCESS" }
end

function getCustomersWithKey(resourceKeyName)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('status')
	filterCondition1:setValue({"ACTIVE"})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({resourceKeyName})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition3 = new("FilterCondition")
	filterCondition3:setField('creditcustomer')
	filterCondition3:setValue({"INVOICE"})
	filterCondition3:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	searchFilter:addCondition(filterCondition3)
	local customers = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))
	if(customers:getList():size() > 0) then
		local expiredTrialCustomers = filterExpiredCustomers(customers:getList())
		return {success = true, data = expiredTrialCustomers}
	else
		return {success = false}
	end
end

function filterExpiredCustomers(customerList)
	for i = 0, customerList:size() - 1, 1 do
		for j = 0, customerList:get(i):getResourceKey():size() -1, 1 do
			if(customerList:get(i):getResourceKey():get(j):getName() == 'TRIAL') then
				local dateHelper = new("FDLDateHelper")
				local createDate = dateHelper:getTimestamp(customerList:get(i):getResourceCreateDate())
				local trialDays = tonumber(customerList:get(i):getResourceKey():get(j):getValue())
				local tresholdDate = dateHelper:getTimestamp() - (trialDays*24*60*60*1000)
				if(tresholdDate > createDate) then
					customerList:get(i):setStatus(new("Status","DISABLED"))
					adminAPI:updateCustomer(customerList:get(i))
					print('Customer ' .. customerList:get(i):getResourceName() .. "Trial Expired! Customer Disabled!")
				end
			end
		end
	end
end

function register()
	return {"trial_customer_expiry_trigger"}
end