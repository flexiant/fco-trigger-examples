-- (c) 2016 Flexiant Ltd
-- Released under the Apache 2.0 Licence - see LICENCE for details

function scheduled_create_snapshot_trigger(p)
	if (p == nil) then
		return {
			ref = "scheduled_create_snapshot",
			name = "Scheduled Create Snapshot Tiggger",
			description = "This will create a snapshot for user if he has right customer key enabled",
			priority = 0,
			triggerType = "SCHEDULED",
			schedule = {frequency = {HOUR = 1}},
			api = "TRIGGER",
			version = 1,
		}
	end

	print("========= SCHEDULED TRIGGER CREATE SNAPSHOT =========")
	local serverList = getServersWithKey('AUTO_SNAPSHOTS', 'MAXSNAPSHOTS')
	for serverUUID, server in pairs(serverList) do
		local newSnapshotDate = p.timeStamp - server.snapshotTime * 60 * 60 * 1000
		local userToken = getUserToken(server.customerUUID)
		userAPI:setSessionUser(userToken)
		createNewSnapshot(server.customerUUID, serverUUID, "SERVER", server.maxSnapshots)

		if (tonumber(server.maxSnapshots) > 0) then
			removeOldSnapshots(serverUUID, server.maxSnapshots);
		end

	end

	local diskList = getDisksWithKey('AUTO_SNAPSHOTS', 'MAXSNAPSHOTS')
	for diskUUID, disk in pairs(diskList) do
		local newSnapshotDate = p.timeStamp - disk.snapshotTime * 60 * 60 * 1000
		local userToken = getUserToken(disk.customerUUID)
		userAPI:setSessionUser(userToken)
		createNewSnapshot(disk.customerUUID, diskUUID, "DISK", disk.maxSnapshots)
		if (tonumber(disk.maxSnapshots) > 0) then
			removeOldSnapshots(diskUUID, disk.maxSnapshots);

		end
	end
	print("======== SCHEDULED TRIGGER CREATE SNAPSHOT COMPLETE=========")
	return {exitState = "SUCCESS"}
end

function removeOldSnapshots(resourceUUID, maxSnapshots)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('parentuuid')
	filterCondition1:setValue({resourceUUID})
	filterCondition1:setCondition(new("Condition", "IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local snapshots = adminAPI:listResources(searchFilter, nil, new("ResourceType", "SNAPSHOT"))
	if (tonumber(snapshots:getList():size()) > tonumber(maxSnapshots)) then
		local snapshotList = {}
		local dateHelper = new("FDLDateHelper")
		for i = 0, snapshots:getList():size() - 1, 1 do
			snapshotList[snapshots:getList():get(i):getResourceUUID()] = dateHelper:getTimestamp(snapshots:getList():get(i):getResourceCreateDate())
			local oldSnapshots = filterOldSnapshots(snapshotList, maxSnapshots);
			for oldSnapshotUUID, oldSnapshotCreateDate in pairs(oldSnapshots) do
				print("======= oldSnapshotUUID to be deleted=========")
				print(oldSnapshotUUID)
				userAPI:deleteResource(oldSnapshotUUID, true, nil)
			end
		end
	end
end

function getUserToken(customerUUID)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourceuuid')
	filterCondition1:setValue({customerUUID})
	filterCondition1:setCondition(new("Condition", "IS_EQUAL_TO"))
	searchFilter:addCondition(filterCondition1)
	local customer = adminAPI:listResources(searchFilter, nil, new("ResourceType", "CUSTOMER"))
	local userEmail = customer:getList():get(0):getUsers():get(0):getEmail()
	return userEmail .. "/" .. customer:getList():get(0):getResourceUUID()
end

function filterOldSnapshots(snapshotTable, maxSnapshots)
	local list = {}
	for name, value in pairs(snapshotTable) do
		list[#list + 1] = name

	end

	function byval(a, b)
		return snapshotTable[a] > snapshotTable[b]
	end

	table.sort(list, byval)

	local response = {}
	for k = maxSnapshots + 1, #list do
		response[list[k]] = snapshotTable[list[k]]
	end

	return response
end

function createNewSnapshot(customerUUID, resourceUUID, type, maxSnapshots)
	print('===== Max Snapshot value taken from key =====')
	print(maxSnapshots)
	if (tostring(maxSnapshots) == '0') then

		print('===== Max snapshot is 0, No snapshots taken =====')
	end

	local snapshotSkeleton = new("Snapshot")
	snapshotSkeleton:setCustomerUUID(customerUUID)
	snapshotSkeleton:setParentUUID(resourceUUID)
	snapshotSkeleton:setType(new("SnapshotType", type))
	local snapshot = userAPI:createSnapshot(snapshotSkeleton, nil)
	local jobQueue = userAPI:waitForJob(snapshot:getResourceUUID(), true)
	print("======== Waiting on create JOB to complete ========")
	print(jobQueue:getResourceUUID())


end

function getDisksWithKey(resourceKeyName, resourceKeyName1)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('status')
	filterCondition1:setValue({"ATTACHED_TO_SERVER"})
	filterCondition1:setCondition(new("Condition", "IS_EQUAL_TO"))
	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name[1]')
	filterCondition2:setValue({resourceKeyName})
	filterCondition2:setCondition(new("Condition", "STARTS_WITH"))

	local filterCondition3 = new("FilterCondition")
	filterCondition3:setField('resourcekey.name[2]')
	filterCondition3:setValue({resourceKeyName1})
	filterCondition3:setCondition(new("Condition", "STARTS_WITH"))

	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)
	searchFilter:addCondition(filterCondition3)
	local disks = adminAPI:listResources(searchFilter, nil, new("ResourceType", "DISK"))
	local responseData = {}
	for i = 0, disks:getList():size() - 1, 1 do
		responseData[disks:getList():get(i):getResourceUUID()] = {snapshotTime = getResourceKeyValue(resourceKeyName, disks:getList():get(i):getResourceKey()), customerUUID = disks:getList():get(i):getCustomerUUID(), maxSnapshots = getResourceKeyValue('MAXSNAPSHOTS', disks:getList():get(i):getResourceKey())}

	end
	return responseData
end

function getServersWithKey(resourceKeyName, resourceKeyName1)
	local searchFilter = new("SearchFilter")
	local filterCondition1 = new("FilterCondition")
	filterCondition1:setField('resourcekey.name[1]')
	filterCondition1:setValue({resourceKeyName})
	filterCondition1:setCondition(new("Condition", "STARTS_WITH"))

	local filterCondition2 = new("FilterCondition")
	filterCondition2:setField('resourcekey.name[2]')
	filterCondition2:setValue({resourceKeyName1})
	filterCondition2:setCondition(new("Condition", "STARTS_WITH"))

	searchFilter:addCondition(filterCondition1)
	searchFilter:addCondition(filterCondition2)

	local servers = adminAPI:listResources(searchFilter, nil, new("ResourceType", "SERVER"))
	local responseData = {}
	for i = 0, servers:getList():size() - 1, 1 do
		responseData[servers:getList():get(i):getResourceUUID()] = {snapshotTime = getResourceKeyValue(resourceKeyName, servers:getList():get(i):getResourceKey()), customerUUID = servers:getList():get(i):getCustomerUUID(), maxSnapshots = getResourceKeyValue('MAXSNAPSHOTS', servers:getList():get(i):getResourceKey())}
	end
	return responseData
end

function getResourceKeyValue(resourceKeyName, resouceKeyList)
	for j = 0, resouceKeyList:size() - 1, 1 do
		if (resouceKeyList:get(j):getName() == resourceKeyName) then
			return resouceKeyList:get(j):getValue()
		end
	end
	return 0;
end

function spairs(t, order)
	-- collect the keys
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end

	-- if order function given, sort by it by passing the table and keys a, b,
	-- otherwise just sort the keys
	if order then
		table.sort(keys, function (a, b) return order(t, a, b) end)
	else
		table.sort(keys)
	end

	-- return the iterator function
	local i = 0
	return function ()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

function register()
	return {"scheduled_create_snapshot_trigger"}
end
