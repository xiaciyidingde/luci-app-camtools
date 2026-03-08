#!/bin/sh
# CamTools - OpenWrt校园网自动登录脚本
# by:夏次一定de

# 配置文件路径
CONFIG_FILE="/etc/config/camtools"
LOG_FILE="/var/log/camtools.log"
LOG_TAG="camtools"
MAX_LOG_LINES=500

# 默认配置
STUDENT_ID=""
PASSWORD=""
SERVER_ADDRESS="192.168.40.2:801"
SERVICE_ENABLED="0"
CHECK_INTERVAL="10"
PING_TARGET="baidu.com"

# 日志函数
log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 写入日志文件
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # 同时写入syslog
    case "$level" in
        INFO)
            logger -t "$LOG_TAG" -p user.info "$message"
            ;;
        ERROR)
            logger -t "$LOG_TAG" -p user.err "$message"
            ;;
        WARNING)
            logger -t "$LOG_TAG" -p user.warning "$message"
            ;;
    esac
    
    # 限制日志文件大小，只保留最后MAX_LOG_LINES行
    if [ -f "$LOG_FILE" ]; then
        local line_count=$(wc -l < "$LOG_FILE")
        if [ "$line_count" -gt "$MAX_LOG_LINES" ]; then
            tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$LOG_FILE.tmp"
            mv "$LOG_FILE.tmp" "$LOG_FILE"
        fi
    fi
}

log_info() {
    log_to_file "INFO" "$1"
    echo "[INFO] $1"
}

log_error() {
    log_to_file "ERROR" "$1"
    echo "[ERROR] $1" >&2
}

log_warning() {
    log_to_file "WARNING" "$1"
    echo "[WARNING] $1"
}

# 加载配置
load_config() {
    STUDENT_ID=$(uci get camtools.config.student_id 2>/dev/null)
    PASSWORD=$(uci get camtools.config.password 2>/dev/null)
    SERVER_ADDRESS=$(uci get camtools.config.server_address 2>/dev/null || echo "192.168.40.2:801")
    SERVICE_ENABLED=$(uci get camtools.config.service_enabled 2>/dev/null || echo "0")
    CHECK_INTERVAL=$(uci get camtools.config.check_interval 2>/dev/null || echo "10")
}

# 验证配置
validate_config() {
    if [ -z "$STUDENT_ID" ] || [ -z "$PASSWORD" ]; then
        log_error "学号或密码未配置"
        return 1
    fi
    
    if [ "$CHECK_INTERVAL" -lt 5 ]; then
        log_warning "检测间隔小于5秒，使用默认值10秒"
        CHECK_INTERVAL=10
    fi
    
    return 0
}

# 获取本地IP
get_local_ip() {
    local ip=$(ip -4 addr show $(uci get network.wan.ifname 2>/dev/null || echo "eth1") 2>/dev/null | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n1)
    
    if [ -z "$ip" ]; then
        ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+')
    fi
    
    echo "$ip"
}

# URL编码
urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o
    
    for pos in $(seq 0 $((strlen-1))); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9])
                o="$c"
                ;;
            *)
                o=$(printf '%%%02X' "'$c")
                ;;
        esac
        encoded="$encoded$o"
    done
    
    echo "$encoded"
}

# 检查网络连接
check_connectivity() {
    ping -c 2 -W 3 "$PING_TARGET" >/dev/null 2>&1
    return $?
}

# 执行登录
perform_login() {
    log_info "开始认证..."
    
    local local_ip=$(get_local_ip)
    if [ -z "$local_ip" ]; then
        log_error "无法获取本地IP地址"
        return 1
    fi
    
    log_info "本地IP: $local_ip"
    
    local server_ip=$(echo "$SERVER_ADDRESS" | cut -d: -f1)
    local server_port=$(echo "$SERVER_ADDRESS" | cut -d: -f2)
    
    local user_account=$(urlencode ",0,${STUDENT_ID}@telecom")
    local user_password=$(urlencode "$PASSWORD")
    local wlan_user_ip=$(urlencode "$local_ip")
    
    local url="http://${SERVER_ADDRESS}/eportal/portal/login"
    url="${url}?callback=dr1003"
    url="${url}&login_method=1"
    url="${url}&user_account=${user_account}"
    url="${url}&user_password=${user_password}"
    url="${url}&wlan_user_ip=${wlan_user_ip}"
    url="${url}&wlan_user_ipv6="
    url="${url}&wlan_user_mac=000000000000"
    url="${url}&wlan_ac_ip=${server_ip}"
    url="${url}&wlan_ac_name="
    url="${url}&jsVersion=4.2"
    url="${url}&terminal_type=1"
    url="${url}&lang=zh-cn"
    url="${url}&v=5616"
    
    local response=$(curl -s --connect-timeout 10 --max-time 10 "$url")
    local curl_exit=$?
    
    if [ $curl_exit -ne 0 ]; then
        log_error "请求超时或网络错误 (exit code: $curl_exit)"
        return 1
    fi
    
    log_info "服务器响应: $response"
    
    if echo "$response" | grep -q '"result":1'; then
        log_info "✓ 登录成功"
        return 0
    elif echo "$response" | grep -q '"ret_code":2' && echo "$response" | grep -q "已经在线"; then
        log_info "✓ 已在线"
        return 0
    elif echo "$response" | grep -q "密码错误"; then
        log_error "✗ 密码错误"
        return 1
    elif echo "$response" | grep -q "AC认证失败"; then
        log_error "✗ AC认证失败"
        return 1
    elif echo "$response" | grep -q "Max user number exceed"; then
        log_error "✗ 用户数超限"
        return 1
    else
        log_error "✗ 未知响应"
        return 1
    fi
}

# 主循环
main_loop() {
    log_info "CamTools服务启动"
    
    # 开机后立即尝试登录一次
    load_config
    if [ "$SERVICE_ENABLED" = "1" ] && validate_config; then
        log_info "开机启动，执行登录"
        perform_login
    fi
    
    while true; do
        load_config
        
        if [ "$SERVICE_ENABLED" != "1" ]; then
            log_info "服务未启用，等待启用..."
            sleep 30
            continue
        fi
        
        if ! validate_config; then
            log_error "配置验证失败，等待配置修复..."
            sleep 30
            continue
        fi
        
        # 配置验证通过，开始监控
        local consecutive_failures=0
        
        while true; do
            # 重新加载配置，检查是否被禁用
            load_config
            if [ "$SERVICE_ENABLED" != "1" ]; then
                log_info "服务已被禁用"
                break
            fi
            
            if check_connectivity; then
                log_info "网络连接正常"
                consecutive_failures=0
            else
                consecutive_failures=$((consecutive_failures + 1))
                log_warning "网络连接失败 (连续${consecutive_failures}次)"
                
                if [ $consecutive_failures -ge 2 ]; then
                    log_info "检测到断网，触发认证"
                    if perform_login; then
                        consecutive_failures=0
                    fi
                fi
            fi
            
            sleep $CHECK_INTERVAL
        done
        
        sleep 5
    done
}

# 手动登录
manual_login() {
    load_config
    
    if ! validate_config; then
        log_error "配置验证失败"
        exit 1
    fi
    
    perform_login
    exit $?
}

# 显示状态
show_status() {
    load_config
    
    echo "CamTools 状态"
    echo "=============="
    echo "服务启用: $SERVICE_ENABLED"
    echo "学号: $STUDENT_ID"
    echo "服务器: $SERVER_ADDRESS"
    echo "检测间隔: ${CHECK_INTERVAL}秒"
    echo ""
    
    if check_connectivity; then
        echo "网络状态: ✓ 已联网"
    else
        echo "网络状态: ✗ 未联网"
    fi
}

# 命令行参数处理
case "$1" in
    start)
        main_loop
        ;;
    login)
        manual_login
        ;;
    status)
        show_status
        ;;
    *)
        echo "用法: $0 {start|login|status}"
        echo "  start  - 启动守护进程"
        echo "  login  - 手动登录一次"
        echo "  status - 显示状态"
        exit 1
        ;;
esac
