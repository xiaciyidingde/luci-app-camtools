-- Copyright 2024
-- Licensed under the Apache License, Version 2.0

local m, s

m = SimpleForm("camtools_logs", translate("日志查看"))
m.reset = false
m.submit = false

s = m:section(SimpleSection)
s.template = "camtools/logs"

return m
