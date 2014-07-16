-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function mailchimp_activation_trigger(p)
	if(p == nil) then
		return {
			ref = "mailchimp_customer_activation_trigger",
			name = "MailChimp customer activation trigger",
			description = "MailChimp add cutomer to mailing list upon customer activation",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"SUCCESSFUL"},
			api = "TRIGGER",
			version = 1,
		}
	end

	local jobType = p.input:getJobType():toString()
	local mailChimpList
	if(jobType == "CREATE_SERVER") then
		mailChimpList = "MAILCHIMP_SERVER_LIST"
	elseif (jobType == "CREATE_CUSTOMER") then
		mailChimpList = "MAILCHIMP_CUSTOMER_LIST"
	elseif (jobType == "CREATE_DEPLOYMENT_INSTANCE") then
		mailChimpList = "MAILCHIMP_BENTOBOX_LIST"
	else
		return { exitState = "SUCCESS" }
	end

	local userUUID = p.input:getUserUUID()
	local beUUID = getbeUUID(userUUID)
	local userData = getUserData(userUUID)
	local mailchimpToken = checkBeKey(beUUID,'MAILCHIMP_TOKEN')
	if(mailchimpToken.success) then
		print("========== MAILCHIMP TRIGGER ACTIVATION ==========")

		local apiToken = splitString(mailchimpToken.keyValue, '-')
		local apiUrl = "https://" .. apiToken[2] .. ".api.mailchimp.com/2.0/lists/subscribe"
		local listID = checkBeKey(beUUID, mailChimpList)
		local params = {apikey = apiToken[1], id= listID.keyValue, email = {email = userData.data.email},merge_vars = {fname = userData.data.firstName, lname = userData.data.lastName}}
		local json = new("JSON")
		params = json:encode(params)
		print('Adding user:' .. userUUID .. ' to MailChimp Subscription list.')
		generate_http_request('',params,apiUrl)
		print("========== MAILCHIMP TRIGGER ACTIVATION COMPLETE ==========")
	end

	return { exitState = "SUCCESS" }
end

function getbeUUID(userUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({userUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local user = adminAPI:listResources(searchFilter,nil,new("ResourceType","USER"))
	if(user:getList():size() > 0) then
		return user:getList():get(0):getBillingEntityUUID()
	end
end

function getUserData(userUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({userUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local user = adminAPI:listResources(searchFilter,nil,new("ResourceType","USER"))
	if(user:getList():size() > 0) then
		local email = user:getList():get(0):getEmail()
		local firstName = user:getList():get(0):getFirstName()
		local lastName = user:getList():get(0):getLastName()
		return {success = true, data = {email = email, firstName = firstName, lastName = lastName}}
	else
		return {success = false , data = {}}
	end
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

function splitString(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	t={} ; i=1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
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
end

function register()
	return {"mailchimp_activation_trigger"}
end
