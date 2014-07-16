-- (c) 2014 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

-- Please specify the token that you get from MixPanel after creating the account
local MIXPANEL_USER_TOKEN = 'PLEASE-ENTER-YOUR-MIXPANEL-TOKEN'

-- No need to change the API URL unless MixPanel changes their endpoint
local MIXPANEL_API = 'https://api.mixpanel.com/'

function register()
	return {
		"mixpanel_post_admin_api_trigger",
		"mixpanel_post_user_api_trigger",
		"mixpanel_post_job_trigger",
		"mixpanel_daily_triggers_perbe"
	}
end

function mixpanel_post_admin_api_trigger(p)

	if(p==nil) then
		return{
			ref = "mixpanel_post_admin_api_trigger",
			name = "Log admin call to MixPanel",
			description = "Trigger to log an admin api call after it has been invoked",
			triggerType = "POST_ADMIN_API_CALL",
			triggerOptions = {"ANY"},
			-- includeCustomerTags={"MIXPANEL_TEST"},
			api = "TRIGGER",
			version = 1,
		}
	end

	local utils = new("Utils")

	if ((utils:stringStartsWith(p.triggerOption,"list"))
		or (utils:stringStartsWith(p.triggerOption,"get"))
		or (utils:stringStartsWith(p.triggerOption,"doQuery"))
		or (utils:stringStartsWith(p.triggerOption,"isPermitted"))
		or (utils:stringStartsWith(p.triggerOption,"checkPermissions"))) then
		return {exitState = "CONTINUE"}
	end

	local data = {}
	data['event'] = "AdminAPI:"..p.triggerOption
	data['properties'] = {}
	data['properties']['distinct_id'] = p.customer:getResourceUUID()
	data['properties']['name'] = p.customer:getResourceName()
	data['properties']['api_user_email'] = p.user:getEmail()
	data['properties']['api_user_uuid'] = p.user:getResourceUUID()
	data['properties']['api_be_uuid'] = p.customer:getBillingEntityUUID()
	data['properties']['api'] = "admin"
	send_mix_pannel_call_event (data)
	create_customer_engage(p.customer:getResourceUUID(), p.customer:getResourceName(),
		p.customer:getBillingEntityUUID(), p.customer:getBillingEntityName())

	return {exitState = "CONTINUE"}

end

function mixpanel_post_user_api_trigger(p)

	if(p==nil) then
		return{
			ref = "mixpanel_post_user_api_trigger",
			name = "Log admin call to MixPanel",
			description = "Trigger to log an user api call after it has been invoked.",
			triggerType = "POST_USER_API_CALL",
			triggerOptions = {"ANY"},
			--includeCustomerTags={"MIXPANEL_TEST"},
			api = "TRIGGER",
			version = 1,
		}
	end

	local utils = new("Utils")

	if ((utils:stringStartsWith(p.triggerOption,"list"))
		or (utils:stringStartsWith(p.triggerOption,"get"))
		or (utils:stringStartsWith(p.triggerOption,"doQuery"))
		or (utils:stringStartsWith(p.triggerOption,"isPermitted"))
		or (utils:stringStartsWith(p.triggerOption,"checkPermissions"))) then
		return {exitState = "CONTINUE"}
	end

	local data = {}
	data['event'] = "UserAPI:"..p.triggerOption
	data['properties'] = {}
	data['properties']['distinct_id'] = p.customer:getResourceUUID()
	data['properties']['name'] = p.customer:getResourceName()
	data['properties']['api_user_email'] = p.user:getEmail()
	data['properties']['api_user_uuid'] = p.user:getResourceUUID()
	data['properties']['api_be_uuid'] = p.customer:getBillingEntityUUID()
	data['properties']['api_type'] = "user"
	--print ("Event is : "..p.triggerOption)
	send_mix_pannel_call_event(data)
	create_customer_engage(p.customer:getResourceUUID(), p.customer:getResourceName(),
		p.customer:getBillingEntityUUID(), p.customer:getBillingEntityName())

	return {exitState = "CONTINUE"}

end

-- Will log jobtype, user who invoked the job the status of the job, job uuid, parent job, item uuid
function mixpanel_post_job_trigger(p)
	if(p==nil) then
		return{
			ref = "mixpanel_post_job_trigger",
			name = "Log customer jobs to MixPanel",
			description = "Trigger to log an customer job to MixPanel.",
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"SUCCESSFUL","FAILED"},
			api = "TRIGGER",
			version = 1,
		}
	end
	local utils = new("Utils")
	local date = new("FDLDateHelper")
	local data = {}
	local job = p.input
	local sTime = date:getTimestamp(job:getResourceCreateDate())
	local eTime = date:getTimestamp(job:getEndTime())
	--print ("Post Job Trigger")
	local jobType = job:getJobType():toString()
	data['event'] = "Job:"..jobType
	data['properties'] = {}
	data['properties']['distinct_id'] = job:getCustomerUUID()
	data['properties']['job_item_uuid'] = job:getItemUUID()
	data['properties']['job_status'] = p.triggerOption
	data['properties']['job_user'] = job:getUserUUID()
	data['properties']['job_be_uuid'] = job:getBillingEntityUUID()
	data['properties']['job_execution_time'] = (eTime - sTime)

	-- This is a
	if (utils:stringStartsWith(jobType,"CREATE_")) then
		-- load the object, without loadchildren
		local object = adminAPI:getResource(job:getItemUUID(), false)
		local jsonStr = object:toJSONString()
		local json = new("JSON")
		local tab = json:decode(jsonStr)
		for k,v in pairs(tab) do
			if (type(v) ~= "table") then
				data['properties'][k] = v
			end
		end
	end
	send_mix_pannel_call_event(data)
	create_customer_engage (job:getCustomerUUID(), job:getCustomerName(),
		job:getBillingEntityUUID(), job:getBillingEntityName())

	return {exitState = "CONTINUE"}

end

-- Will log units are which have been used per billing entity
function mixpanel_daily_triggers_perbe(p)
	if(p == nil) then
		return{
			ref="mixpanel_daily_triggers_perbe",
			name="MixPanel Daily BE stats trigger",
			description = "Send the daily unit usage, invoice data per BE to MixPanel",
			priority = 0,
			triggerType="SCHEDULED",
			schedule={start={HOUR=23,MINUTE=59,SECOND=59},frequency={HOUR=24}},
			api="TRIGGER",
			version=1
		}
	end

	-- Aggregation for daily units
	local dateHelper = new("FDLDateHelper")
	local rundate = (p.input[1] - 10000)
	local transactionDate = dateHelper:getString(rundate, "yyyy-MM-dd")

	local searchFilter = new("SearchFilter")
	local dateFilterCondition = new("FilterCondition")
	dateFilterCondition:setCondition(new("Condition","IS_EQUAL_TO"))
	dateFilterCondition:setValue({transactionDate})
	dateFilterCondition:setField("transactionDate")

	searchFilter:addCondition(dateFilterCondition)

	local queryLimit = new("QueryLimit")
	queryLimit:setLoadChildren(false)
	queryLimit:setMaxRecords(200)

	local orderByDate = new("OrderedField")
	orderByDate:setFieldName("billingEntityUUID")
	orderByDate:setSortOrder(new("ResultOrder","ASC"))

	queryLimit:getOrderBy():add(orderByDate)

	local aggregationSUM = new("Aggregation","SUM")
	local query = new("Query")
	query:setResourceType(new("ResourceType","UNIT_TRANSACTION_SUMMARY"))
	query:setSearchFilter(searchFilter)
	query:setLimit(queryLimit)
	query:setGroupByFields({"billingEntityUUID"})
	query:setOutputFields({"transactionDate"})
	query:setOutputFields({"billingEntityUUID"})

	local aggregationFieldDebits = new("AggregationField")
	aggregationFieldDebits:setAggregationFunction(aggregationSUM)
	aggregationFieldDebits:setFieldName("unitDebits")

	local aggregationFieldCredits = new("AggregationField")
	aggregationFieldCredits:setAggregationFunction(aggregationSUM)
	aggregationFieldCredits:setFieldName("unitCredits")

	query:setAggregationFields(new("List"))
	query:getAggregationFields():add(aggregationFieldDebits)
	query:getAggregationFields():add(aggregationFieldCredits)

	local queryIterator = adminAPI:runAggregationQuery(query)

	local be_unit_map = {}

	while queryIterator:hasNext() do
		local resultRow = queryIterator:next()
		local resultRowMap = resultRow:getColumnMap()

		local data = {}
		data['event'] = "Summary:DAILY_BE_UNITS"
		data['properties'] = {}
		data['properties']['distinct_id'] = resultRowMap:get("billingEntityUUID")
		data['properties']['date'] = transactionDate
		data['properties']['unit_debits'] = resultRowMap:get("SUM(unitDebits)")
		data['properties']['unit_credits'] = resultRowMap:get("SUM(unitCredits)")
		be_unit_map[resultRowMap:get("billingEntityUUID")] = data
	end

	-- Aggregation for daily invoices
	local toDate = (p.input[1] / 1000)
	local fromDate = ((toDate - 86400) + 1)

	searchFilter = new("SearchFilter")
	dateFilterCondition = new("FilterCondition")
	dateFilterCondition:setCondition(new("Condition","BETWEEN"))
	dateFilterCondition:setValue({fromDate.."", toDate..""})
	dateFilterCondition:setField("invoiceDate")
	searchFilter:addCondition(dateFilterCondition)

	--[[
	dateFilterCondition = new("FilterCondition")
	dateFilterCondition:setCondition(new("Condition","IS_LESS_THAN_OR_EQUAL_TO"))
	dateFilterCondition:setValue({toDate..""})
	dateFilterCondition:setField("invoiceDate")
	searchFilter:addCondition(dateFilterCondition) --]]

	query = new("Query")
	query:setResourceType(new("ResourceType","INVOICE"))
	query:setSearchFilter(searchFilter)
	queryLimit:setMaxRecords(200)
	query:setLimit(queryLimit)
	query:setGroupByFields({"billingEntityUUID"})
	query:setOutputFields({"billingEntityUUID"})

	local aggregationCOUNT = new("Aggregation","COUNT")
	local aggregationFieldCount = new("AggregationField")
	aggregationFieldCount:setAggregationFunction(aggregationCOUNT)
	aggregationFieldCount:setFieldName("invoiceNo")

	local aggregationFieldSUM = new("AggregationField")
	aggregationFieldSUM:setAggregationFunction(aggregationSUM)
	aggregationFieldSUM:setFieldName("invoiceTotalInc")

	query:setAggregationFields(new("List"))
	query:getAggregationFields():add(aggregationFieldCount)
	query:getAggregationFields():add(aggregationFieldSUM)

	local be_invoice_map = {}
	queryIterator = adminAPI:runAggregationQuery(query)
	while queryIterator:hasNext() do
		local resultRow = queryIterator:next()
		local resultRowMap = resultRow:getColumnMap()

		local data = {}
		data['event'] = "Summary:DAILY_BE_INVOICES"
		data['properties'] = {}
		data['properties']['distinct_id'] = resultRowMap.get("billingEntityUUID")
		data['properties']['date'] = transactionDate
		data['properties']['num_of_created_invoices'] = resultRowMap.get("COUNT(invoiceNo)")
		data['properties']['total_of_pament_created'] = resultRowMap.get("SUM(invoiceTotalInc)")
		data['properties']['num_of_paid_invoices'] = 0
		data['properties']['total_of_pament_received'] = 0
		be_invoice_map[resultRowMap.get("billingEntityUUID")] = data
	end

	-- Now go and find out the paid details
	searchFilter:removeCondition("invoiceDate")
	dateFilterCondition = new("FilterCondition")
	dateFilterCondition:setCondition(new("Condition","BETWEEN"))
	dateFilterCondition:setValue({fromDate.."", toDate..""})
	dateFilterCondition:setField("paidDate")
	searchFilter:addCondition(dateFilterCondition)

	--[[
	dateFilterCondition = new("FilterCondition")
	dateFilterCondition:setCondition(new("Condition","IS_LESS_THAN_OR_EQUAL_TO"))
	dateFilterCondition:setValue({toDate..""})
	dateFilterCondition:setField("paidDate")
	searchFilter:addCondition(dateFilterCondition)--]]

	queryLimit:setMaxRecords(200)

	queryIterator = adminAPI:runAggregationQuery(query)
	while queryIterator:hasNext() do
		local resultRow = queryIterator:next()
		local resultRowMap = resultRow:getColumnMap()

		local data = be_invoice_map[resultRowMap.get("billingEntityUUID")]
		if (data ~= nil) then
			data['properties']['num_of_paid_invoices'] = resultRowMap.get("COUNT(invoiceNo)")
			data['properties']['total_of_pament_received'] = resultRowMap.get("SUM(invoiceTotalInc)")
		else
			data = {}
			data['event'] = "Summary:DAILY_BE_INVOICES"
			data['properties'] = {}
			data['properties']['distinct_id'] = resultRowMap.get("billingEntityUUID")
			data['properties']['date'] = transactionDate
			data['properties']['num_of_created_invoices'] = 0
			data['properties']['total_of_pament_created'] = 0
			data['properties']['num_of_paid_invoices'] = resultRowMap.get("COUNT(invoiceNo)")
			data['properties']['total_of_pament_received'] = resultRowMap.get("SUM(invoiceTotalInc)")
			be_invoice_map[resultRowMap.get("billingEntityUUID")] = data
		end
	end

	-- Now get all the billing entities loop through them
	queryLimit:setMaxRecords(200)
	queryLimit:setFrom(0)
	local loop = true
	local count = 0;
	--local json = new ("JSON")
	while loop == true do
		local beList = adminAPI:listResources(nil, queryLimit, new ("ResourceType", "BILLING_ENTITY"))
		local tot = beList:getTotalCount()
		local ite = beList:getList():iterator()
		while (ite:hasNext()) do
			local be = ite:next()
			create_be_engage (be);
			-- Send unit transaction data
			local data = be_unit_map[be:getResourceUUID()]
			if (data == nil) then
				data = {}
				data['event'] = "Summary:DAILY_BE_UNITS"
				data['properties'] = {}
				data['properties']['distinct_id'] = be:getResourceUUID()
				data['properties']['date'] = transactionDate
				data['properties']['unit_debits'] = 0
				data['properties']['unit_credits'] = 0
			end
			--print (json:encode(data))
			send_mix_pannel_call_event (data)

			-- Send the invoice data
			data = be_invoice_map[be:getResourceUUID()]
			if (data == nil) then
				data = {}
				data['event'] = "Summary:DAILY_BE_INVOICES"
				data['properties'] = {}
				data['properties']['distinct_id'] = be:getResourceUUID()
				data['properties']['date'] = transactionDate
				data['properties']['num_of_created_invoices'] = 0
				data['properties']['total_of_pament_created'] = 0
				data['properties']['num_of_paid_invoices'] = 0
				data['properties']['total_of_pament_received'] = 0
			end
			--print (json:encode(data))
			send_mix_pannel_call_event (data)
			count = count + 1
		end
		if (count < tot) then
			queryLimit:setFrom((count - 1))
		else
			loop = false
		end
	end
end

-- Will log units are which have been used per customer
function mixpanel_daily_unit_trigger_customer(p)
	if(p == nil) then
		return{
			ref="mixpanel_daily_unit_trigger_customer",
			name="Mixpanel Daily units per Customer",
			description = "Send the daily unit usage per Customer to mixpanel",
			priority = 0,
			triggerType="SCHEDULED",
			schedule={start={HOUR=00,MINUTE=0,SECOND=0},frequency={HOUR=24}},
			api="TRIGGER",
			version=1
		}
	end
end

-- The data is a lua table that that we need to send out to the mix pannel
function send_mix_pannel_call_event (data)
	local mix_pannel_url = MIXPANEL_API.."track/"
	data['properties']['token'] = MIXPANEL_USER_TOKEN
	data['properties']['verbose'] = 1

	-- Need to get a JSON object do the a string encoding
	local json = new("JSON")
	local jsonReturn = json:encode(data)

	-- Need to make a connection to the API and send the data

	local hasher = new("FDLHashHelper")
	local base64 = hasher:toBase64(jsonReturn)

	local simplehttp = new("simplehttp")
	local url = mix_pannel_url.."?data="..base64
	--print (url)
	local httpconn = simplehttp:newConnection({url=url})
	local returnString = ""

	if(httpconn:get( function (val)
				returnString = returnString..val
				return true
				end)) then

		else
			returnString = "CURL error "..httpconn:getLastError()
		end

		local httpcode = httpconn:getHTTPStatusCode()
		httpconn:disconnect()
		--[[local ret = "Return HTTPcode: "..httpcode
		ret = ret.." data: "..returnString
		print (ret)--]]
	end

	function create_customer_engage(uuid, name, beuuid, bename)
		local data = {}
		data['$distinct_id'] = uuid
		data['$set'] = {}
		data['$set']['$name'] = name
		data['$set']['$beUUID'] = beuuid
		data['$set']['$beName'] = bename
		send_mix_pannel_call_engage (data)
	end

	function create_be_engage(be)
		local data = {}
		data['$distinct_id'] = be:getResourceUUID()
		data['$set'] = {}
		data['$set']['$beName'] = be:getResourceName()
		data['$set']['$parentBEUUID'] = be:getParentUUID()
		send_mix_pannel_call_engage (data)
	end

	function send_mix_pannel_call_engage (data)
		local mix_pannel_url = MIXPANEL_API.."engage/"
		data['$token'] = MIXPANEL_USER_TOKEN

		-- Need to get a JSON object do the a string encoding
		local json = new("JSON")
		local jsonReturn = json:encode(data)

		-- Need to make a connection to the API and send the data

		local hasher = new("FDLHashHelper")
		local base64 = hasher:toBase64(jsonReturn)

		local simplehttp = new("simplehttp")
		local url = mix_pannel_url.."?data="..base64.."&verbose=1"
		--print (url)
		local httpconn = simplehttp:newConnection({url=url})
		local returnString = ""

		if(httpconn:get(
				function (val)
					returnString = returnString..val
					return true
					end)) then
			else
				returnString = "CURL error "..httpconn:getLastError()
			end

			local httpcode = httpconn:getHTTPStatusCode()
			httpconn:disconnect()
			--[[local ret = "Return HTTPcode: "..httpcode
			ret = ret.." data: "..returnString
			print (ret)--]]
		end

