-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function auto_image_publish_protect(p)
	if(p == nil) then
		return {
			ref = "auto_image_publish_protect",
			name = "Automatically publish and/or protect Images",
			description = "This trigger will publish and/ord protect Images based on customer keys.",
			priority = 0,
			triggerType = "POST_JOB_STATE_CHANGE",
			triggerOptions = {"SUCCESSFUL"},
			api = "TRIGGER",
			version = 1,
		}
	end

	if(p.input:getJobType():toString() == "CREATE_IMAGE_TEMPLATE") then
		print("========== AUTO IMAGE PUBLISH/PROTECT ==========")

		local userToken = getUserToken(p.input:getCustomerUUID())
		userAPI:setSessionUser(userToken)

		local publishCheck = checkCustomerKey(p.input:getCustomerUUID(),'AUTO_PUBLISH_IMAGE')
		if(publishCheck.success) then
			userAPI:publishImage(p.input:getItemUUID(),nil,nil)
		end

		local protectCheck = checkCustomerKey(p.input:getCustomerUUID(),'AUTO_PROTECT_IMAGE')
		if(protectCheck.success) then
			local updatedImage = getResource(p.input:getItemUUID(),new("ResourceType","IMAGE"))
			local newImagePermissions = prepareNewPermissions()
			local parsedPermissions = parseKeyValues(protectCheck.keyValue)
			newImagePermissions = applyNewPermissions(newImagePermissions,parsedPermissions)
			updatedImage.data:setUserPermission(newImagePermissions)
			userAPI:modifyImage(updatedImage.data,nil)
		end

		print("========== AUTO IMAGE PUBLISH/PROTECT COMPLETE ==========")
	end
	return { exitState = "SUCCESS" }
end

function applyNewPermissions(newImagePermissions,parsedPermissions)
	for parseKeyName,parseKeyValue in pairs(parsedPermissions) do
		if(parseKeyName == 'Can be detached') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanBeDetachedFromServer(true)
			elseif (parseKeyValue == 'No') then
				newImagePermissions:setCanBeDetachedFromServer(false)
			end
		elseif (parseKeyName == 'Can be 2nd Disk') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanBeSecondaryDisk(true)
			elseif (parseKeyValue == 'No') then
				newImagePermissions:setCanBeSecondaryDisk(false)
			end
		elseif (parseKeyName == 'Can clone') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanClone(true)
			elseif (parseKeyValue == 'No')
				then newImagePermissions:setCanClone(false)
			end
		elseif (parseKeyName == 'Can console') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanConsole(true)
			elseif (parseKeyValue == 'No') then
				newImagePermissions:setCanConsole(false)
			end
		elseif (parseKeyName == 'Can create server') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanCreateServer(true)
			elseif (parseKeyValue == 'No') then
				newImagePermissions:setCanCreateServer(false)
			end
		elseif (parseKeyName == 'Can have additional disks') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanHaveAdditionalDisks(true)
			elseif (parseKeyValue == 'No') then
				newImagePermissions:setCanHaveAdditionalDisks(false)
			end
		elseif (parseKeyName == 'Can image') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanImage(true)
			elseif (parseKeyValue == 'No') then
				newImagePermissions:setCanImage(false)
			end
		elseif (parseKeyName == 'Can snapshot') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanSnapshot(true)
			elseif (parseKeyValue == 'No') then
				newImagePermissions:setCanSnapshot(false)
			end
		elseif (parseKeyName == 'Can start') then
			if(parseKeyValue == 'Yes') then
				newImagePermissions:setCanStart(true)
			elseif (parseKeyValue == 'No') then
				newImagePermissions:setCanStart(false)
			end
		else
			print('Wrong Value set in the Customer Key!')
		end
	end
	return newImagePermissions
end

function prepareNewPermissions()
	local newImagePermissions = new("ImagePermission")
	newImagePermissions:setCanClone(true)
	newImagePermissions:setCanSnapshot(true)
	newImagePermissions:setCanBeDetachedFromServer(true)
	newImagePermissions:setCanBeSecondaryDisk(true)
	newImagePermissions:setCanConsole(true)
	newImagePermissions:setCanCreateServer(true)
	newImagePermissions:setCanHaveAdditionalDisks(true)
	newImagePermissions:setCanImage(true)
	newImagePermissions:setCanStart(true)
	return newImagePermissions
end

function getUserToken(customerUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({customerUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local customer = adminAPI:listResources(searchFilter,nil,new("ResourceType","CUSTOMER"))

	local userEmail = customer:getList():get(0):getUsers():get(0):getEmail()

	return userEmail .. "/" .. customer:getList():get(0):getResourceUUID()
end

function getResource(resourceUUID,resourceType)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({resourceUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local resource = adminAPI:listResources(searchFilter,nil,resourceType)
	if(resource:getList():size() == 1) then
		return {success = true, data = resource:getList():get(0)}
	else
		return {success = false}
	end
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

function parseKeyValues(parseString)
	local userPermissions = split(parseString,';')
	local permission = {}
	for key,value in pairs(userPermissions) do
		local temp = split(value,':')
		permission[temp[1]] = temp[2]
	end
	return permission
end

function split(str, pat)
	local t = {} -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(t,cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end

function vardump(value, depth, key)
	local linePrefix = ""
	local spaces = ""

	if key ~= nil then
		linePrefix = "["..key.."] = "
	end

	if depth == nil then
		depth = 0
	else
		depth = depth + 1
		for i=1, depth do spaces = spaces .. " " end
	end

	if type(value) == 'table' then
		mTable = getmetatable(value)
		if (mTable == nil) then
			print(spaces ..linePrefix.."(table) ")
		else
			print(spaces .."(metatable) ")
			value = mTable
		end
		for tableKey, tableValue in pairs(value) do
			vardump(tableValue, depth, tableKey)
		end
	elseif(value == nil or type(value) == 'function' or type(value) == 'thread' or type(value) == 'userdata') then
		print(spaces..tostring(value))
	else
		print(spaces..linePrefix.."("..type(value)..") "..tostring(value))
	end
end

function register()
	return {"auto_image_publish_protect"}
end
