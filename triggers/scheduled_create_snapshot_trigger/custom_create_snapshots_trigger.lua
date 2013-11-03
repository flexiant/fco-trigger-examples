-- (c) 2013 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function scheduled_create_snapshot_trigger(p)
	if(p == nil) then
		return {
			ref = "scheduled_create_snapshot",
			name = "Scheduled Create Snapshot Tiggger",
			description = "This will create a snapshot for user if he has right customer key enabled",
			priority = 0,
			triggerType = "SCHEDULED",
			schedule={frequency={HOUR=1}},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("======== SCHEDULED TRIGGER CREATE SNAPSHOT =========")
	local serverList = getServersWithKey('AUTO_SNAPSHOTS')
	for serverUUID,server in pairs(serverList) do 
		local newSnapshotDate = os.time()-server.snapshotTime*60*60*1000
		local checkSnapshot = checkSnapshotDate(serverUUID,newSnapshotDate)
		if(checkSnapshot) then		
			createNewSnapshot(server.customerUUID, serverUUID, "SERVER")
		end
	end
	local diskList = getDisksWithKey('AUTO_SNAPSHOTS')
	for diskUUID,disk in pairs(diskList) do 
		local newSnapshotDate = os.time()-disk.snapshotTime*60*60*1000
		local checkSnapshot = checkSnapshotDate(diskUUID,newSnapshotDate)
		if(checkSnapshot) then		
			createNewSnapshot(disk.customerUUID, diskUUID, "DISK")
		end
	end
	print("======== SCHEDULED TRIGGER CREATE SNAPSHOT COMPLETE=========")
	return { exitState = "SUCCESS" }
end

function createNewSnapshot(customerUUID,resourceUUID,type)
	local snapshotSkeleton = new("Snapshot")
	snapshotSkeleton:setCustomerUUID(customerUUID)
	snapshotSkeleton:setParentUUID(resourceUUID)
	snapshotSkeleton:setType(new("SnapshotType",type))
	print('Creating new snapshot for customer :' .. customerUUID .. ' ResourceUUID : ' .. resourceUUID .. ' Type:' .. type)
	userAPI:createSnapshot(snapshotSkeleton,nil)
end

function getServersWithKey(resourceKeyName)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('status')
	filterCondition1:setValue({"STOPPED"})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({resourceKeyName})
	filterCondition2:setCondition(new("Condition","STARTS_WITH"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local servers = adminAPI:listResources(searchFilter,nil,new("ResourceType","SERVER"))
	local responseData = {}
	for i = 0, servers:getList():size() - 1, 1 do
		responseData[servers:getList():get(i):getResourceUUID()] = {snapshotTime = getResourceKeyValue(resourceKeyName,servers:getList():get(i):getResourceKey()) , customerUUID = servers:getList():get(i):getCustomerUUID()}
		print("printing the server list entry "..i.." server name "..servers:getList():get(i):getResourceName())
	end
	return responseData
end

function getDisksWithKey(resourceKeyName)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('status')
	filterCondition1:setValue({"ATTACHED_TO_SERVER"})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name')
	filterCondition2:setValue({resourceKeyName})
	filterCondition2:setCondition(new("Condition","STARTS_WITH"))
	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	local servers = adminAPI:listResources(searchFilter,nil,new("ResourceType","DISK"))
	local responseData = {}
	for i = 0, servers:getList():size() - 1, 1 do
		responseData[servers:getList():get(i):getResourceUUID()] = {snapshotTime = getResourceKeyValue(resourceKeyName,servers:getList():get(i):getResourceKey()) , customerUUID = servers:getList():get(i):getCustomerUUID()}
	end
	return responseData
end

function getResourceKeyValue(resourceKeyName,resouceKeyList)
	for j = 0, resouceKeyList:size() - 1, 1 do
		if(resouceKeyList:get(j):getName() == resourceKeyName) then
			return resouceKeyList:get(j):getValue()
		end
	end
end

function checkSnapshotDate(serverUUID,newDate)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('parentuuid')
	filterCondition1:setValue({serverUUID})
	filterCondition1:setCondition(new("Condition","IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local queryLimit = new("QueryLimit")
	local orderedField = new("OrderedField")
	orderedField:setFieldName('resourcecreatedate')
	orderedField:setSortOrder(new("ResultOrder","DESC"))
	local list = new("List")
	list:add(orderedField)
	queryLimit:setOrderBy(list)
	queryLimit:setMaxRecords(1)
	queryLimit:setLoadChildren(false)
	local snapshots = adminAPI:listResources(searchFilter,queryLimit,new("ResourceType","SNAPSHOT"))
	if(snapshots:getList():size()==1) then
		local dateHelper = new("FDLDateHelper")
		local dateCreated = dateHelper:getTimestamp(snapshots:getList():get(0):getResourceCreateDate())
		if(dateCreated-newDate<0) then
			return true
		else
			return false
		end
	else
		return true
	end
end

function register()
	return {"scheduled_create_snapshot_trigger"}
end