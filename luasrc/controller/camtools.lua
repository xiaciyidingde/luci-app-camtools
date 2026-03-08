module("luci.controller.camtools", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/camtools") then
		return
	end

	-- 主入口，默认显示设置页面
	entry({"admin", "services", "camtools"}, 
	      firstchild(), 
	      _("校园网登录"), 60)
	
	-- 登录设置页面
	entry({"admin", "services", "camtools", "settings"}, 
	      cbi("camtools/settings"), 
	      _("登录设置"), 1)
	
	-- 日志查看页面
	entry({"admin", "services", "camtools", "logs"}, 
	      form("camtools/logs"), 
	      _("日志查看"), 2)
	
	-- API 接口 - 状态查询
	entry({"admin", "services", "camtools", "status"}, 
	      call("action_status"))
	
	-- API 接口 - 手动登录
	entry({"admin", "services", "camtools", "login"}, 
	      call("action_manual_login"))
	
	-- API 接口 - 重启服务
	entry({"admin", "services", "camtools", "restart"}, 
	      call("action_restart_service"))
	
	-- API 接口 - 启动服务
	entry({"admin", "services", "camtools", "start"}, 
	      call("action_start_service"))
	
	-- API 接口 - 停止服务
	entry({"admin", "services", "camtools", "stop"}, 
	      call("action_stop_service"))
	
	-- API 接口 - 获取日志
	entry({"admin", "services", "camtools", "get_logs"}, 
	      call("action_get_logs"))
end

function action_status()
	local nixio = require "nixio"
	local uci = require "luci.model.uci".cursor()
	local sys = require "luci.sys"
	local http = require "luci.http"
	
	local enabled = uci:get("camtools", "config", "service_enabled") or "0"
	
	-- Check actual service running status using init script
	local service_running = false
	local status_output = sys.exec("/etc/init.d/camtools status 2>&1")
	local status_code = sys.exec("/etc/init.d/camtools status >/dev/null 2>&1; echo $?"):gsub("\n", "")
	
	-- status code 0 means running, 3 means stopped/disabled
	if status_code == "0" then
		service_running = true
	end
	
	local connected = "unknown"
	local ping_result = sys.exec("ping -c 1 -W 2 baidu.com >/dev/null 2>&1 && echo 'success' || echo 'failed'")
	if ping_result:match("success") then
		connected = "已联网"
	elseif ping_result:match("failed") then
		connected = "未联网"
	end
	
	local last_auth_time = ""
	if nixio.fs.access("/var/log/camtools.log") then
		local log_cmd = "grep '认证' /var/log/camtools.log | tail -n 1 | awk -F'[][]' '{print $2}'"
		local log_result = sys.exec(log_cmd)
		if log_result and log_result ~= "" then
			last_auth_time = log_result:gsub("\n", "")
		end
	end
	
	http.prepare_content("application/json")
	http.write_json({
		enabled = (enabled == "1"),
		service_running = service_running,
		connected = connected,
		last_auth_time = last_auth_time
	})
end

function action_manual_login()
	local sys = require "luci.sys"
	local uci = require "luci.model.uci".cursor()
	local http = require "luci.http"
	
	local enabled = uci:get("camtools", "config", "service_enabled") or "0"
	if enabled ~= "1" then
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			message = "服务未启用"
		})
		return
	end
	
	local result = sys.exec("/usr/bin/camtools.sh login 2>&1")
	local exit_code = sys.exec("echo $?"):gsub("\n", "")
	
	if exit_code == "0" then
		http.prepare_content("application/json")
		http.write_json({
			success = true,
			message = "手动登录成功"
		})
	else
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			message = "手动登录失败: " .. result
		})
	end
end

function action_get_logs()
	local nixio = require "nixio"
	local http = require "luci.http"
	local logs = {}
	
	local log_file = "/var/log/camtools.log"
	
	if nixio.fs.access(log_file) then
		local f = io.open(log_file, "r")
		if f then
			local lines = {}
			for line in f:lines() do
				table.insert(lines, line)
			end
			f:close()
			
			-- 只返回最后200行
			local start_idx = math.max(1, #lines - 199)
			for i = start_idx, #lines do
				local line = lines[i]
				-- 解析格式: [2024-01-15 10:30:45] [INFO] message
				local timestamp, level, message = line:match("%[([^%]]+)%]%s*%[([^%]]+)%]%s*(.+)")
				if timestamp and level and message then
					table.insert(logs, {
						timestamp = timestamp,
						level = level,
						message = message
					})
				end
			end
		end
	end
	
	-- 反转顺序，最新的在前
	local reversed_logs = {}
	for i = #logs, 1, -1 do
		table.insert(reversed_logs, logs[i])
	end
	
	http.prepare_content("application/json")
	http.write_json({
		logs = reversed_logs
	})
end

function action_restart_service()
	local sys = require "luci.sys"
	local http = require "luci.http"
	
	-- 停止服务
	local stop_result = sys.exec("/etc/init.d/camtools stop 2>&1")
	
	-- 等待1秒
	os.execute("sleep 1")
	
	-- 启动服务
	local start_result = sys.exec("/etc/init.d/camtools start 2>&1")
	
	-- 等待1秒后检查状态
	os.execute("sleep 1")
	local status_code = sys.exec("/etc/init.d/camtools status >/dev/null 2>&1; echo $?"):gsub("\n", "")
	
	if status_code == "0" then
		http.prepare_content("application/json")
		http.write_json({
			success = true,
			message = "服务重启成功"
		})
	else
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			message = "服务重启失败，请查看日志"
		})
	end
end

function action_start_service()
	local sys = require "luci.sys"
	local http = require "luci.http"
	
	-- 启动服务
	local start_result = sys.exec("/etc/init.d/camtools start 2>&1")
	
	-- 等待1秒后检查状态
	os.execute("sleep 1")
	local status_code = sys.exec("/etc/init.d/camtools status >/dev/null 2>&1; echo $?"):gsub("\n", "")
	
	if status_code == "0" then
		http.prepare_content("application/json")
		http.write_json({
			success = true,
			message = "服务启动成功"
		})
	else
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			message = "服务启动失败，请查看日志"
		})
	end
end

function action_stop_service()
	local sys = require "luci.sys"
	local http = require "luci.http"
	
	-- 停止服务
	local stop_result = sys.exec("/etc/init.d/camtools stop 2>&1")
	
	-- 等待1秒后检查状态
	os.execute("sleep 1")
	local status_code = sys.exec("/etc/init.d/camtools status >/dev/null 2>&1; echo $?"):gsub("\n", "")
	
	if status_code ~= "0" then
		http.prepare_content("application/json")
		http.write_json({
			success = true,
			message = "服务停止成功"
		})
	else
		http.prepare_content("application/json")
		http.write_json({
			success = false,
			message = "服务停止失败"
		})
	end
end
