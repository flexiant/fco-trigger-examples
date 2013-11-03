function hipchat_messaging_service_trigger(p)
	if(p == nil) then
		return {
			ref = "hipchat_messaging_service_trigger",
			name = "Hipchat Messaging Service Trigger",
			description = "Send notifications of new customer activations, new server creations and new invoices created to a Hipchat channel",
			priority = 0,
			triggerType = "POST_CREATE",
			triggerOptions = {"INVOICE","SERVER","CUSTOMER"},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("======== HIPCHAT TRIGGER ACTIVATION =========")
	local apiToken = checkBeKey(p.beUUID,"HIPCHAT_API_TOKEN")
	if(apiToken.success)then
		local url = "https://api.hipchat.com/v1/rooms/message?format=json&auth_token=" .. apiToken.keyValue
		local msg = ""
		if(p.triggerOption == "INVOICE") then
			msg = "New+Invoice+(no.+".. p.input:getInvoiceNo()  ..")+created+for+customer " .. p.customer:getResourceName()
		elseif (p.triggerOption == "SERVER") then
			msg = "New+Server+(".. p.input:getResourceName()  ..")+created+for+customer " .. p.customer:getResourceName()
		elseif (p.triggerOption == "CUSTOMER") then
			msg = "New+Customer+(".. p.input:getResourceName()  ..")+created"
		end
		local roomId = checkBeKey(p.beUUID,"HIPCHAT_ROOM_ID")
		if(roomId.success) then
			sendHipchatMessage(url,roomId.keyValue,msg)
		else
			print('Room ID Key not found!')
		end
	else
		print('API Token Key not found!')
	end
	print("======== HIPCHAT TRIGGER ACTIVATION COMPLETE=========")

	return { exitState = "SUCCESS" }
end

function sendHipchatMessage(url,roomId,message)
	local params = "room_id=".. roomId .. "&from=FCONotification&message=" .. message
	print('Sending message notificatoin to HipChat!')
	generate_http_request('',params,url)
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
	return {"hipchat_messaging_service_trigger"}
end