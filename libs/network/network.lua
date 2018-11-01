local log = log and log(...) or print

local undef = nil
local lsocket = require "lsocket"

local network = {}

local listen = {}
local readfds = {}
local writefds = {}
local connection = {}
local connecting = {}

function network.listen(address, port)
	local fd = assert(lsocket.bind(address, port))
	listen[fd] = true
	table.insert(readfds, fd)
end

local function new_connection(fd, addr, port)
	local obj = { _fd = fd , _read = {}, _write = {}, _peer = addr .. ":" .. port }
	connection[fd] = obj
	table.insert(readfds, fd)
	return obj
end

function network.connect(address, port)
	local fd, err = lsocket.connect(address, port)
	if fd == nil then
		log("Connect to %s %s error : %s", address, port, err)
		return nil, err
	end
	connecting[fd] = true
	table.insert(writefds, fd)
	return new_connection(fd, address, port)
end

local function remove_fd(tbl, fd)
	for i = 1,#tbl do
		if fd == tbl[i] then
			table.remove(tbl, i)
			return
		end
	end
end

local function close_fd(fd)
	fd:close()
	connecting[fd] = undef
	connection[fd] = undef
	listen[fd] = undef
	remove_fd(readfds, fd)
	remove_fd(writefds, fd)
end

function network.close(obj)
	close_fd(obj._fd)
end

function network.send(obj, data)
	local sending = obj._write
	if #sending == 0 then
		table.insert(writefds, obj._fd)
	end
	table.insert(sending, 1, data)
end

local function dispatch(fd)
	-- read from fd
	local obj = connection[fd]
	local data, err = fd:recv()
	if not data then
		if data then
			-- socket error
			log("Error : %s %s", obj._peer, err)
		end
		log("Closed : %s", obj._peer)
		close_fd(fd)
	else
		table.insert(obj._read, data)
	end
end

local function sendout(fd)
	local obj = connection[fd]
	local sending = obj._write

	while true do
		local data = table.remove(sending)
		if data == nil then
			break
		end
		local nbytes, err = fd:send(data)
		if nbytes then
			if nbytes < #data then
				table.insert(sending, data:sub(nbytes+1))
				return
			end
		else
			if err then
				log("Error : %s %s", obj._peer, err)
			end
			table.insert(sending, data)	-- push back
			return
		end
	end

	remove_fd(writefds, fd)
end

function network.dispatch(objs, interval)
	local rd, wt = assert(lsocket.select(readfds, writefds, interval))
	if not rd then
		if rd == nil then
			log("Select error : ", wt)
		end
		return
	end
	for _, fd in ipairs(rd) do
		if listen[fd] then
			local client, address, port = fd:accept()
			if not client then
				if client == nil then
					log("Accept error : ", address)
				end
			else
				local obj = new_connection(client, address, port)
				log("Accept : %s", obj._peer)
			end
		else
			dispatch(fd)
			table.insert(objs, connection[fd])
		end
	end
	for _, fd in ipairs(wt) do
		if connecting[fd] then
			local obj = connection[fd]
			local ok, err = fd:status()
			if not ok then
				log("Connect %s error : %s", obj._peer, err)
				connecting[fd] = undef
				close_fd(fd)
			else
				log("%s connected", obj._peer)
				sendout(fd)
			end
		else
			sendout(fd)
		end
	end
	return objs
end

return network
