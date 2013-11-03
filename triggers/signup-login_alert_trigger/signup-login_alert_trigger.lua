function signup_alert(p)
	if(p == nil) then
		return {
			ref = "signup_alert",
			name = "Alert on signup",
			description = "This trigger will automatically send alerts or notifications based on customer sigenup",
			priority = 0,
			triggerType = "POST_CREATE",
			triggerOptions = {"USER"},
			api = "TRIGGER",
			version = 1,
		}
	end

	local toEmail = checkBeKey(p.beUUID, 'SIGNUP_LOGIN_EMAIL')
	if(toEmail.success) then
		print("========== ALERT ON SINGUP ==========")
		local beMail = getBEMail(p.beUUID)

		local message = "Customer " .. p.input:getFirstName() .. " " .. p.input:getLastName() .. "has successfully signed up!"
		print('Sending SignUp email to :' .. toEmail.keyValue)
		sendMail(toEmail.keyValue, beMail, message)

		print("========== ALERT ON SINGUP COMPLETE==========")
	end
	return { exitState = "SUCCESS" }
end

function login_alert(p)
	if(p == nil) then
		return {
			ref = "login_alert",
			name = "Alert on login",
			description = "This trigger will automatically send mail to user after h",
			priority = 0,
			triggerType = "POST_AUTH",
			triggerOptions = {"SUCCESS"},
			api = "TRIGGER",
			version = 1,
		}
	end

	local toEmail = checkBeKey(p.beUUID, 'SIGNUP_LOGIN_EMAIL')
	if(toEmail.success) then
		print("========== ALERT ON LOGIN ==========")
		local beMail = getBEMail(p.beUUID)

		if not (string.find(p.input, beMail) or string.find(p.input, "jobs")) then
			local userEmail = p.user:getEmail()
			local message = "User " .. p.user:getFirstName() .. " " .. p.user:getLastName() .. " has successfully logged in."
			print('Sending login email to : ' .. toEmail.keyValue)
			sendMail(toEmail.keyValue, beMail, message)
		end

		print("========== ALERT ON LOGIN ==========")
	end
	return { exitState = "SUCCESS" }
end

function sendMail(toEmail, beMail, msg)
	local emailHelper = new("FDLEmailHelper")
	emailHelper(toEmail, beMail, beMail, nil, nil, "Signup-Login Alert", msg, nil)
end

function getUserEmail(customerUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({customerUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local customer = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))

	local userEmail = customer:getList():get(0):getUsers():get(0):getEmail()

	return userEmail
end

function getBEMail(beUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('billingentityuuid')
	filterCondition1:setValue({beUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('status')
	filterCondition2:setValue({"ADMIN"})
	filterCondition2:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)

	local customer = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))

	local userEmail = customer:getList():get(0):getUsers():get(0):getEmail()
	return userEmail
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
		"signup_alert",
	--"login_alert"
	}
end
