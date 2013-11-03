-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function scheduled_ducksboard_update(p)
	if(p == nil) then
		return {
			ref = "scheduled_ducksboard",
			name = "Ducksboard Dashboard Updates",
			description = "Sends all relevant information to duckboard",
			priority = 0,
			triggerType = "SCHEDULED",
			schedule={frequency={MINUTE=5}},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("======== SCHEDULED TRIGGER DUCKSBOARD =========")
	local json = new("JSON")
	local serversRunning = {value = get_running_server_count()}
	serversRunning = json:encode(serversRunning)
	local customers = {value = get_customer_number()}
	customers = json:encode(customers)
	local newCustomers = {value = get_new_customer_count()}
	newCustomers = json:encode(newCustomers)
	local newInvoices = {value = get_new_invoice_count()}
	newInvoices = json:encode(newInvoices)
	local token = checkBeKey(p.beUUID,'DUCKSBOARD_API_TOKEN')
	if(token.success) then
		local ducksBoardUrls = getDucksBoardUrls(p.beUUID)
		if(ducksBoardUrls.success) then
			print('Pushing Data to Ducksboard.')
			generate_http_request(token.keyValue,serversRunning, ducksBoardUrls.urls.serverDataUrl)
			print('-Server data pushed.')
			generate_http_request(token.keyValue,customers, ducksBoardUrls.urls.customerDataUrl)
			print('-Customer data pushed.')
			generate_http_request(token.keyValue,newCustomers, ducksBoardUrls.urls.newCustomerDataUrl)
			print('-New Customer data pushed')
			generate_http_request(token.keyValue,newInvoices, ducksBoardUrls.urls.newInvoiceDataUrl)
			print('-New Invoices data pushed.')
		end
	end
	print("======== SCHEDULED TRIGGER DUCKSBOARD COMPLETE=========")
	return { exitState = "SUCCESS" }
end

function get_customer_number()
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('status')
	filterCondition1:setValue({"ACTIVE"})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local customers = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))
	return customers:getList():size()
end

function get_new_customer_count()
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('status')
	filterCondition1:setValue({"ACTIVE"})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcecreatedate')
	local dateHelper = new("FDLDateHelper")
	local lastDay = dateHelper:getString(dateHelper:getTimestamp()-(24*60*60*1000),"yyyy-MM-ddhh:mm:ssZ")
	filterCondition2:setValue({lastDay})
	filterCondition2:setCondition(new("Condition","IS_GREATER_THAN"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local newCustomers = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))
	return newCustomers:getList():size()
end

function get_new_invoice_count()
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourcecreatedate')
	local dateHelper = new("FDLDateHelper")
	local lastDay = dateHelper:getString(dateHelper:getTimestamp()-(24*60*60*1000),"yyyy-MM-ddhh:mm:ssZ")
	filterCondition1:setValue({lastDay})
	filterCondition1:setCondition(new("Condition","IS_GREATER_THAN"))
	searchFilter:addCondition(filterCondition1)
	local newInvoices = adminAPI:listResources(searchFilter,nil,new("ResourceType","INVOICE"))
	return newInvoices:getList():size()
end

function get_running_server_count()
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('status')
	filterCondition1:setValue({"RUNNING"})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local serversRunning = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))
	return serversRunning:getList():size()
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

function getDucksBoardUrls(beUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({beUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local billingEntity = adminAPI:listResources(searchFilter,nil,new("ResourceType","BILLING_ENTITY"))
	if(billingEntity:getList():size() == 1) then
		local urls = {}
		for i = 0, billingEntity:getList():get(0):getResourceKey():size() - 1, 1 do
			if(billingEntity:getList():get(0):getResourceKey():get(i):getName() == "SERVER_DATA_URL") then
				urls['serverDataUrl'] = billingEntity:getList():get(0):getResourceKey():get(i):getValue()
			elseif(billingEntity:getList():get(0):getResourceKey():get(i):getName() == "CUSTOMER_DATA_URL") then
				urls['customerDataUrl'] = billingEntity:getList():get(0):getResourceKey():get(i):getValue()
			elseif(billingEntity:getList():get(0):getResourceKey():get(i):getName() == "NEW_CUSTOMER_DATA_URL") then
				urls['newCustomerDataUrl'] = billingEntity:getList():get(0):getResourceKey():get(i):getValue()
			elseif(billingEntity:getList():get(0):getResourceKey():get(i):getName() == "NEW_INVOICE_DATA_URL") then
				urls['newInvoiceDataUrl'] = billingEntity:getList():get(0):getResourceKey():get(i):getValue()
			end
		end
		return {success = true, urls = urls}
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

	if(type(token) == "table") then
		httpconn:setBasicAuth(token.username,token.password)
	else
		httpconn:setBasicAuth(token,'')
	end


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
	return {"scheduled_ducksboard_update"}
end