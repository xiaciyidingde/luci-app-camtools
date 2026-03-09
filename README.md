# luci-app-camtools

OpenWrt/ImmortalWrt 江西应用校园网自动登录插件

[![GitHub](https://img.shields.io/badge/GitHub-luci--app--camtools-blue?logo=github)](https://github.com/xiaciyidingde/luci-app-camtools)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](https://opensource.org/licenses/Apache-2.0)

## 简介

luci-app-camtools 是一个纯Shell脚本实现的OpenWrt/ImmortalWrt插件，用于江西应用校园网自动认证（dr.com认证）。系统监控网络连接状态，当互联网访问中断时自动登录校园网。

## 项目背景

当你有多个联网设备，台式电脑，笔记本电脑，手机，esp8266……但一个校园网账户只能登录一个设备，更何况有些设备无法进行校园网认证登录，因此，我急需一个可以登录校园网的AP设备，这个基于OpenWrt/ImmortalWrt的项目由此而来。

通过这个项目，路由器将成为校园网的认证客户端，所有连接到路由器的设备都可以共享网络，轻松实现：

- **多设备共享**：电脑、手机同时在线
- **智能设备联网**：ESP8266等设备无需认证即可上网
- **自动化管理**：断网自动重连，开机自动登录，无需人工干预

## 特性

- ✅ 断网时自动登录
- ✅ 开机自动登录
- ✅ LuCI Web界面设置
- ✅ 实时状态监控
- ✅ Shell脚本实现

<div align="center">

### 界面展示
<img src="https://github.com/xiaciyidingde/luci-app-camtools/blob/master/img/1.png" width="800" alt="主界面v3.9.8">

<img src="https://github.com/xiaciyidingde/luci-app-camtools/blob/master/img/2.png" width="800" alt="主界面v3.9.8">
</div>


## 安装

### 方法1：使用打包脚本（推荐）

项目提供了跨平台的 Python 打包脚本，支持 Windows/Linux/macOS。

**注意**：脚本默认为 `aarch64_cortex-a53` 架构编译，如果你的设备是其他架构，请先修改 `build_ipk.py` 中的 `ARCH` 变量。

常见架构：
- **aarch64_cortex-a53**（默认）
- **aarch64_cortex-a72**
- **arm_cortex-a7**
- **arm_cortex-a9** 
- **mipsel_24kc**
- **x86_64**

#### 使用方法（所有平台通用）

```bash
# 1. 克隆项目
git clone https://github.com/xiaciyidingde/luci-app-camtools.git package/luci-app-camtools
cd package/luci-app-camtools

# 2. 修改架构（如果需要）
# 编辑 build_ipk.py，找到 ARCH 变量并修改为你的设备架构
# Linux/macOS: nano build_ipk.py
# Windows: notepad build_ipk.py

# 3. 运行打包脚本
python build_ipk.py
# 或 python3 build_ipk.py (某些 Linux 系统)

# 4. 生成的 IPK 包在 bin/ 目录
# Linux/macOS: ls bin/
# Windows: dir bin\
```

**注意**：`build_ipk.sh` 脚本仍然保留用于 Linux/macOS 环境，但推荐使用 Python 脚本以获得更好的跨平台兼容性。

### 方法2：通过 OpenWrt SDK 编译

```bash
git clone https://github.com/xiaciyidingde/luci-app-camtools.git package/luci-app-camtools

# 2. 在 menuconfig 中选择包
make menuconfig
# 导航到: LuCI -> 3. Applications -> luci-app-camtools
# 选择 <M> - 生成独立IPK
# 选择 <*> - 键编译进固件
# 保存并退出

# 3. 编译软件包
make package/luci-app-camtools/compile V=s

# 4. 生成包索引
make package/index

# 5. 查找生成的IPK文件
find bin/ -name "luci-app-camtools*.ipk"
# IPK通常在: bin/packages/你的架构/luci/ 或 bin/packages/你的架构/base/
```

**重要提示**：
- 必须在 menuconfig 中选中包，否则编译时不会生成 IPK


## 配置过LuCI Web界面配置

1. 登录路由器管理界面
2. 进入 "服务" -> "校园网登录"
3. 填写学号、密码
4. 启用服务
5. 保存并应用

### 通过命令行配置

```bash
# 配置学号和密码
uci set camtools.config.student_id='学号'
uci set camtools.config.password='密码'

# 配置服务器地址
# uci set camtools.config.server_address='192.168.40.2:801'

# 配置检测间隔（默认10秒，最小5秒）
# uci set camtools.config.check_interval='10'

# 启用服务
uci set camtools.config.service_enabled='1'

# 提交配置
uci commit camtools

# 启动服务
/etc/init.d/camtools start
```

## 使用

### 查看服务状态
```bash
/etc/init.d/camtools status
```

### 手动触发登录
```bash
/usr/bin/camtools.sh login
```

### 重启服务
```bash
/etc/init.d/camtools restart
```

### 查看日志
```bash
# 查看日志文件
cat /var/log/camtools.log

# 查看系统日志
logread | grep camtools
```

## 配置说明

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| student_id | 学号（最大64字符） | 空 |
| password | 密码（最大64字符） | 空 |
| server_address | 服务器地址（格式：IP:端口） | 192.168.40.2:801 |
| service_enabled | 服务启用状态（0=禁用，1=启用） | 0 |
| check_interval | 网络检测间隔（秒，最小值5） | 10 |


## 项目信息

- **项目名称**：luci-app-camtools
- **GitHub 仓库**：https://github.com/xiaciyidingde/luci-app-camtools
- **许可证**：Apache License 2.0
- **作者**：夏次一定de
