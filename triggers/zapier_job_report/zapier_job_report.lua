-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function add_job_report_zapier(p)
	if(p == nil) then
		return {
			ref = "add_job_report_zapier",
			name = "Add a job to Zapier",
			description = "This trigger will add a job to Zapier whenever a new Job is created.",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"ANY"},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("========== ZAPIER JOB TRIGGER ==========")
	local js = new ("JSON")
	local input = {  
		itemName = p.input:getItemName(),
		itemType = p.input:getItemType():toString(),
		itemDescription = p.input:getItemDescription(),
		billingEntityUUID = p.input:getBillingEntityUUID(),
		billingEntityName = p.input:getBillingEntityName(),
		customerName = p.input:getCustomerName(),
		customerUUID = p.input:getCustomerUUID(),
    	errorCode = p.input:getErrorCode(),
		jobInfo = p.input:getInfo(),
		jobStatus = p.input:getStatus():toString(),
		userName = p.input:getUserName(),
		userUUID = p.input:getUserUUID(),
		-- user details --
    	userEmail = p.user:getEmail(),
    	userFullName = p.user:getFirstName().." "..p.user:getLastName(),
		userID = p.user:getUserId(),
		--customer details--
		customerResourceName = p.customer:getResourceName(),
		customerId = p.customer:getCustomerId(),
		customerStatus = p.customer:getStatus():toString()
		
	}
	local params = js:encode(input)
	local token = checkBeKey(p.customer:getBillingEntityUUID(),"ZAPIER_WEB_HOOK_URL")
	print('Sending Job information to Zapier.')
	generate_http_request("",params, token)

	print("========== ZAPIER JOB TRIGGER COMPLETE ==========")
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

function generate_http_request(token,params,url)
	local headers = {}
	headers['Content-Type'] = "application/x-www-form-urlencoded"

	local simplehttp = new("simplehttp")
	local httpconn = simplehttp:newConnection({url=url})
	httpconn:setRequestHeaders(headers)

	httpconn:setBasicAuth(token,'')

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

	httpcode = httpconn:getResponseHeaders()
	httpconn:disconnect()

	local js = new ("JSON")
	local jsonReturnString = js:decode(returnString)
end

function register()
	return {"add_job_report_zapier"}
end