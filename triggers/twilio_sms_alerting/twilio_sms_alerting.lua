-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function auto_sms_send(p)
	if(p == nil) then
		return {
			ref = "auto_sms_send",
			name = "Automatically Send SMS",
			description = "This trigger will automatically send SMS messages via Twilio if server starts fail",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"FAILED"},
			api = "TRIGGER",
			version = 1,
		}
	end
	
	if(p.input:getJobType() == new("JobType","START_SERVER")) then
		print("========== AUTO SEND SMS TRIGGER ==========")
		
		local customerUUID = p.input:getCustomerUUID()
		local twilio_account_sid = checkCustomerKey(customerUUID, "TWILIO_ACCOUNT_SID")
		local twilio_account_token = checkCustomerKey(customerUUID, "TWILIO_ACCOUNT_TOKEN")
		local twilio_to_number = checkCustomerKey(customerUUID, "TWILIO_TO_NUMBER")
		local twilio_from_number = checkCustomerKey(customerUUID, "TWILIO_FROM_NUMBER")
		if(twilio_account_sid.success and twilio_account_token.success and twilio_from_number.success and twilio_to_number.success) then
			local smsData = getUserData(customerUUID)
			smsData.serverId = p.input:getItemUUID()
			smsData.serverName = p.input:getItemName()
			smsData.toNumber = twilio_to_number.keyValue
			smsData.fromNumber = twilio_from_number.keyValue

			local url = "https://api.twilio.com/2010-04-01/Accounts/".. twilio_account_sid.keyValue .."/Messages.json"
			local token = {
				username = twilio_account_sid.keyValue,
				password = twilio_account_token.keyValue
			}

			sendSms(url, token, smsData)
		else
			print("Please input configurable values into customer keys!")
		end
	end
	print("========== AUTO SEND SMS TRIGGER COMPLETE ==========")
	return { exitState = "SUCCESS" }
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

function getUserData(customerUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({customerUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local customer = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))

	local allUserData = customer:getList():get(0):getUsers():get(0)
	local userData = {
		email = allUserData:getEmail(),
		firstName = allUserData:getFirstName(),
		lastName = allUserData:getLastName(),
	}
	return userData
end

function sendSms(url, token, data)
	local msg = "Dear "..data.firstName .. " " .. data.lastName .. ", your server \"".. data.serverName .. "\" (".. data.serverId .. ") start has failed!"
	local params = "From=%2B"..data.fromNumber.."&To=%2B" .. data.toNumber .."&Body="..msg
	local smsParams = "From=" .. data.fromNumber .. "&To=" .. data.toNumber .. "&Body=" .. msg
	print('Sending SMS to :' .. data.toNumber)
	generate_http_request(token,params,url)
end

function generate_http_request(token,params,url)
	local headers = {}
	headers['Content-Type'] = "application/x-www-form-urlencoded"

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
	return {"auto_sms_send"}
end
