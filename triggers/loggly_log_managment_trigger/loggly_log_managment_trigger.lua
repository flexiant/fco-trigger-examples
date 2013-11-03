-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function loggly_log_managment_trigger(p)
	if(p == nil) then
		return {
			ref = "loggly_log_managment_trigger",
			name = "Loggly log managment Trigger",
			description = "Independent logging mechanism done by loggly",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"ANY"},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("========== LOGGLY TRIGGER ACTIVATION ==========")
	
	local customerToken = checkBeKey(p.beUUID,'LOGGLY_CUSTOMER_TOKEN')
	if(customerToken.success) then
		local url = 'http://logs-01.loggly.com/inputs/' .. customerToken.keyValue
		local params = getParams(p.input)
		print('Sending log params to loggly.')
		generate_http_request('',params,url)
	else
		print('Loggly Customer Token key not set!')
	end
	
	print("========== LOGGLY TRIGGER COMPLETE ==========")
	
	return { exitState = "SUCCESS" }
end

function getParams(input)
	local json = new("JSON")
	local output = {
		information = input:getInfo(),
		error_code = input:getErrorCode(),
		job_item_type = input:getItemType():toString(),
		job_item_description = input:getItemDescription(),
		job_item_name = input:getItemName(),
		job_type = input:getJobType():toString(),
		job_status = input:getStatus():toString()
	}
	local jsonReturn = json:encode(output)
	
	return jsonReturn
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
	return {"loggly_log_managment_trigger"}
end