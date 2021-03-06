require("util")
local socket = require("c.socket")
local epoll = require("c.epoll")

local EventLoop = {}

function EventLoop:add(handler)
	self.handlers[handler.fd] = handler
	epoll.ctl(self.epollfd, epoll.CTL_ADD, handler.fd)
end

function EventLoop:del(handler)
	self.handlers[handler.fd] = nil
	epoll.ctl(self.epollfd, epoll.CTL_DEL, handler.fd)
end

function EventLoop:run()
	local result = {}
	while true do
		for i = 1, epoll.wait(self.epollfd, result) do
			local v = result[i]
			local handler = self.handlers[v.fd]
			local mask = v.mask
			if mask & epoll.MASK_READ then
				handler:on_readable(self)
			end
			if mask & epoll.MASK_WRITE then
                print('写数据')
				handler:on_writeable(self)
			end
		end
	end
end

local function new_event_loop()
  print("EventLoop", EventLoop)
  return new_object(EventLoop, {
		handlers = {},
		epollfd = epoll.create(),
  })
end

local Listener = {}
function Listener:on_writeable(eventloop) end
function Listener:on_error(eventloop) end
function Listener:on_readable(eventloop)
	local fd, err = socket.accept(self.fd)
	if not err then
		self:on_conn(fd, eventloop)
	end
end
-- Listener instance should overload it
function Listener:on_conn(fd, event) 
	print('accept a new connection fd=', fd)
	socket.close(fd)
end

local function new_listener(addr)
	local fd, err = socket.listen(addr)
	if err then
		print(err)
		return nil
	end
  return new_object(Listener, {
		fd = fd,
		addr = addr,
  })
end

local BufferQueue = {}

local function new_buffer_queue()
  return new_object(BufferQueue, {
		head = 1,
		tail = 1,
		-- available data in [head, tail)
		deque = {},
		enque = {},
  })
end

function BufferQueue:push(x)
	table.insert(self.enque, x)
end

function BufferQueue:pop()
	if self.head == self.tail then
		self.head = 1
		self.deque, self.enque = self.enque, self.deque
		self.tail = #self.deque+1
	end

	if self.head < self.tail then
		local ret = self.deque[self.head]
		self.deque[self.head] = nil
		self.head = self.head + 1
		return ret
	end
end

function BufferQueue:push_back(x)
	self.head = self.head - 1
	self.deque[self.head] = x
end

local Conn = {}

function Conn:add2event(el)
	self.eventloop = el
	el:add(self)
end
function Conn:on_error(eventloop) 
--	eventloop.del(self)
--	socket.close(self.fd) 
end
-- Conn instance should overload on_read
function Conn:on_read(data) end
function Conn:on_readable(eventloop) 
	local data = socket.read(self.fd)
	self:on_read(data)
end

function Conn:write(data)
	self.buffer:push(data)
	local epollfd = self.eventloop.epollfd
	epoll.ctl(epollfd, epoll.CTL_WRITE, self.fd, true)
    print('conn:write 数据推了并设置了write')
end
function Conn:on_writeable(eventloop)
	local data = self.buffer:pop()
	while data do
        print('这时是真的写数据了', data)
		local len = socket.write(self.fd, data)
		if len < string.len(data) then
			local rem = string.sub(data)
			self.buffer:push_back(rem)
			return
		end

		data = self.buffer:pop()
	end
	epoll.ctl(eventloop.epollfd, epoll.CTL_WRITE, self.fd, false)
    print('退出呀')
end

local function new_conn(fd)
  return new_object(Conn, {
		fd = fd,
		buffer = new_buffer_queue()
  })
end

local M = {
  new_event_loop = new_event_loop,
  new_listener = new_listener,
  new_connection = new_conn,
  EventLoop = EventLoop,
  Listener = Listener,
  Connection = Conn
}

return M
