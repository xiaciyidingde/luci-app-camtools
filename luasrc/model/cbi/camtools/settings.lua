-- Copyright 2024
-- Licensed under the Apache License, Version 2.0

local m, s, o

-- Read version from file
local version = "unknown"
local version_file = io.open("/etc/camtools/version", "r")
if version_file then
	version = version_file:read("*line") or "unknown"
	version_file:close()
end

m = Map("camtools", translate("江西应用校园网登录工具 v" .. version))

-- Add status section at the top
s = m:section(SimpleSection)
s.template = "camtools/status"

s = m:section(TypedSection, "camtools", translate("基本设置"))
s.anonymous = true
s.addremove = false

-- Service enabled switch
o = s:option(Flag, "service_enabled", translate("启用服务"))
o.default = "0"
o.rmempty = false

-- Override the write function to start/stop service when enabled flag changes
function o.write(self, section, value)
	local old_value = self.map:get(section, self.option)
	Flag.write(self, section, value)
	
	-- If value changed, start or stop the service
	if old_value ~= value then
		local sys = require "luci.sys"
		if value == "1" then
			-- Service was enabled, start it
			sys.exec("/etc/init.d/camtools start >/dev/null 2>&1")
		else
			-- Service was disabled, stop it
			sys.exec("/etc/init.d/camtools stop >/dev/null 2>&1")
		end
	end
end

-- Student ID field
o = s:option(Value, "student_id", translate("学号"))
o.datatype = "maxlength(64)"
o.rmempty = false

function o.validate(self, value, section)
	if not value or value == "" then
		return nil, translate("学号不能为空")
	end
	if #value > 64 then
		return nil, translate("学号长度不能超过64个字符")
	end
	return value
end

-- Password field
o = s:option(Value, "password", translate("密码"))
o.password = true
o.datatype = "maxlength(64)"
o.rmempty = false

function o.validate(self, value, section)
	if not value or value == "" then
		return nil, translate("密码不能为空")
	end
	if #value > 64 then
		return nil, translate("密码长度不能超过64个字符")
	end
	return value
end

-- Server address field
o = s:option(Value, "server_address", translate("服务器地址"),
	translate("校园网认证服务器地址，格式为 IP:端口"))
o.default = "192.168.40.2:801"
o.placeholder = "192.168.40.2:801"
o.rmempty = false

function o.validate(self, value, section)
	if not value or value == "" then
		return nil, translate("服务器地址不能为空")
	end
	
	local ip, port = value:match("^([^:]+):(%d+)$")
	if not ip or not port then
		return nil, translate("服务器地址格式错误，应为 IP:端口")
	end
	
	local parts = {}
	for part in ip:gmatch("%d+") do
		table.insert(parts, tonumber(part))
	end
	
	if #parts ~= 4 then
		return nil, translate("IP地址格式错误")
	end
	
	for _, part in ipairs(parts) do
		if part < 0 or part > 255 then
			return nil, translate("IP地址范围错误")
		end
	end
	
	local port_num = tonumber(port)
	if port_num < 1 or port_num > 65535 then
		return nil, translate("端口号范围错误（1-65535）")
	end
	
	return value
end

-- Check interval field
o = s:option(Value, "check_interval", translate("检测间隔（秒）"),
	translate("网络状态检测的时间间隔，最小值为5秒"))
o.datatype = "min(5)"
o.default = "10"
o.placeholder = "10"

function o.validate(self, value, section)
	local num = tonumber(value)
	if not num then
		return nil, translate("检测间隔必须是数字")
	end
	if num < 5 then
		return nil, translate("检测间隔不能小于5秒")
	end
	return value
end

-- Add manual login button section
s = m:section(SimpleSection)
s.template = "camtools/manual_login"

return m
