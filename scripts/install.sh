#!/bin/sh

# 自动修复 Windows 换行符问题（如果从 Windows 上传）
if grep -q $'\r' "$0" 2>/dev/null; then
    sed -i 's/\r$//' "$0"
    exec sh "$0" "$@"
fi

# install.sh - WiFi Manager 一键安装/更新脚本
# 此脚本由 OTA 更新自动调用，也可手动执行
# 
# 使用方法：
#   首次安装: sh install.sh
#   OTA 更新: 由系统自动调用

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志文件
LOG_FILE="/etc/wx/wx-wireless.log"
MAX_LOG_SIZE=102400  # 100KB

# 写入日志文件（带自动轮转）
write_log() {
    local log_entry="$(date '+%Y-%m-%d %H:%M:%S') - [INSTALL] $1"
    
    # 确保目录存在
    mkdir -p /etc/wx
    
    # 检查日志文件大小，超过100KB则保留最后50行
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$log_size" -gt "$MAX_LOG_SIZE" ]; then
            local tmp_file=$(mktemp)
            tail -n 50 "$LOG_FILE" > "$tmp_file"
            mv "$tmp_file" "$LOG_FILE"
        fi
    fi
    
    echo "$log_entry" >> "$LOG_FILE"
}

log_info() { printf "${GREEN}[INFO]${NC} %s\n" "$1"; write_log "$1"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; write_log "[WARN] $1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; write_log "[ERROR] $1"; }

# 检测并安装 git（用于 OTA 更新）
install_git_if_needed() {
    if ! command -v git >/dev/null 2>&1; then
        log_info "检测到 git 未安装，正在安装..."
        if opkg update >/dev/null 2>&1 && opkg install git git-http >/dev/null 2>&1; then
            log_info "  ✓ git 已安装"
        else
            log_warn "  git 安装失败，OTA 更新功能可能不可用"
        fi
    fi
}

# 获取脚本所在目录的父目录（openwrt目录）
SCRIPT_DIR=$(dirname "$(dirname "$0")")

echo ""
echo "═══════════════════════════════════════"
echo "  WiFi Manager 安装脚本"
echo "═══════════════════════════════════════"
log_info "安装源: $SCRIPT_DIR"

# 1. 安装前端文件 → /www/wx/
if [ -d "$SCRIPT_DIR/wx" ]; then
    log_info "安装前端文件..."
    mkdir -p /www/wx
    # 使用 cp -a 保留所有文件属性，先删除目标再复制整个目录内容（包括隐藏文件如.ver）
    rm -rf /www/wx/*
    cp -a "$SCRIPT_DIR/wx/." /www/wx/
    log_info "  → /www/wx/"
fi

# 2. 安装 CGI 脚本 → /www/cgi-bin/
if [ -d "$SCRIPT_DIR/cgi-bin" ]; then
    log_info "安装 CGI 脚本..."
    mkdir -p /www/cgi-bin
    cp -r "$SCRIPT_DIR/cgi-bin/"* /www/cgi-bin/
    # 转换换行符（Windows CRLF → Unix LF）并设置权限
    for f in /www/cgi-bin/*.sh; do
        [ -f "$f" ] && sed -i 's/\r$//' "$f" && chmod +x "$f"
    done
    log_info "  → /www/cgi-bin/"
fi

# 3. 安装 RPCD 脚本 → /usr/libexec/rpcd/
if [ -d "$SCRIPT_DIR/rpcd" ]; then
    log_info "安装 RPCD 脚本..."
    mkdir -p /usr/libexec/rpcd
    cp -r "$SCRIPT_DIR/rpcd/"* /usr/libexec/rpcd/
    # 转换换行符并设置权限
    if [ -f "/usr/libexec/rpcd/wx-wireless" ]; then
        sed -i 's/\r$//' /usr/libexec/rpcd/wx-wireless
        chmod +x /usr/libexec/rpcd/wx-wireless
    fi
    log_info "  → /usr/libexec/rpcd/"
fi

# 4. 安装 ACL 权限配置 → /usr/share/rpcd/acl.d/
if [ -d "$SCRIPT_DIR/acl.d" ]; then
    log_info "安装 ACL 配置..."
    mkdir -p /usr/share/rpcd/acl.d
    cp -r "$SCRIPT_DIR/acl.d/"* /usr/share/rpcd/acl.d/
    log_info "  → /usr/share/rpcd/acl.d/"
fi

# 5. 初始化配置文件 → /etc/wx/ (仅当不存在时)
mkdir -p /etc/wx

# 5.1 热点配置文件
if [ -f "$SCRIPT_DIR/etc/wx/wifi-config.json" ]; then
    if [ ! -f "/etc/wx/wifi-config.json" ]; then
        log_info "初始化热点配置文件..."
        cp "$SCRIPT_DIR/etc/wx/wifi-config.json" /etc/wx/
        log_info "  → /etc/wx/wifi-config.json"
    else
        log_warn "热点配置文件已存在，跳过覆盖"
    fi
fi

# 5.2 用户设置文件 (推送、安全等可调参数)
if [ -f "$SCRIPT_DIR/etc/wx/wx_settings.conf" ]; then
    if [ ! -f "/etc/wx/wx_settings.conf" ]; then
        log_info "初始化用户设置文件..."
        cp "$SCRIPT_DIR/etc/wx/wx_settings.conf" /etc/wx/
        # 转换换行符（Windows CRLF → Unix LF）
        sed -i 's/\r$//' /etc/wx/wx_settings.conf
        log_info "  → /etc/wx/wx_settings.conf"
    else
        log_warn "用户设置文件已存在，跳过覆盖"
    fi
fi

# 6. 安装卸载脚本 → /etc/wx/
if [ -f "$SCRIPT_DIR/scripts/uninstall.sh" ]; then
    log_info "安装卸载脚本..."
    cp "$SCRIPT_DIR/scripts/uninstall.sh" /etc/wx/
    # 转换换行符并设置权限
    sed -i 's/\r$//' /etc/wx/uninstall.sh
    chmod +x /etc/wx/uninstall.sh
    log_info "  → /etc/wx/uninstall.sh"
fi

# 7. 安装 git（确保 OTA 更新可用）
install_git_if_needed

# 8. 重启相关服务
log_info "重启服务..."
if /etc/init.d/rpcd restart 2>/dev/null; then
    log_info "  ✓ rpcd 已重启"
else
    log_warn "  rpcd 重启失败（可能未运行）"
fi

if /etc/init.d/uhttpd restart 2>/dev/null; then
    log_info "  ✓ uhttpd 已重启"
else
    log_warn "  uhttpd 重启失败（可能未运行）"
fi

# 读取安装后的版本号
NEW_VERSION="未知"
if [ -f "/www/wx/.ver" ]; then
    NEW_VERSION=$(cat "/www/wx/.ver" 2>/dev/null)
fi

echo ""
echo "═══════════════════════════════════════"
log_info "安装完成！版本: $NEW_VERSION"
echo "═══════════════════════════════════════"
echo ""
