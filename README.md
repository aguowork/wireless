# WiFi Manager for OpenWrt

OpenWrt 无线中继管理系统 - 基于 Vue3 + LuCI RPC

## 功能特性

### 📡 中继模式
- 📶 **开启中继** - 一键连接上级路由器热点
- 🔌 **关闭中继** - 智能倒计时+轮询检测，避免WiFi断开导致的失败
- 🔍 **扫描附近热点** - 双频并发扫描(2.4G/5G)，增量合并结果，显示扫描时间

### ⚡ 智能切换
- 🔄 **自动切换** - 断网时自动切换到备用热点
- ⏰ **定时检测** - 0-59分钟可配置，0为关闭

### 🔧 系统功能
- 🔐 **安全认证** - 基于 Token 的安全认证机制
- 📲 **WXPusher推送** - 状态变化实时通知
- 🔄 **OTA 更新** - 支持在线检查和更新

## 目录结构

```
├── wx/              → /www/wx/              # 前端文件
├── cgi-bin/         → /www/cgi-bin/         # CGI 认证脚本
├── rpcd/            → /usr/libexec/rpcd/    # RPCD 后端脚本
├── acl.d/           → /usr/share/rpcd/acl.d/# ACL 权限配置
├── etc/wx/          → /etc/wx/              # 配置文件目录
│   ├── wifi-config.json                    # 热点配置文件
│   └── wx_settings.conf                    # 用户设置文件
├── scripts/
│   ├── install.sh                          # 一键安装脚本
│   └── uninstall.sh     → /etc/wx/uninstall.sh  # 一键卸载脚本
└── README.md                               # 项目文档
```

## 安装方法

### 方法一：一键安装（推荐）

```bash
# 下载最新代码并安装（不需要 git）
wget -O /tmp/wx.tar.gz https://gitee.com/okuni/wireless/repository/archive/main.tar.gz &&
mkdir -p /tmp/wx-install && tar -xzf /tmp/wx.tar.gz -C /tmp/wx-install &&
sh /tmp/wx-install/*/scripts/install.sh &&
rm -rf /tmp/wx-install /tmp/wx.tar.gz
```

> 💡 **说明**：安装脚本会自动处理 Windows 换行符、设置文件权限、重启服务，无需任何手动配置。
>
> 没有 `wget` 的固件可换成 `uclient-fetch -O /tmp/wx.tar.gz <地址>` 或 `curl -fsSL -o /tmp/wx.tar.gz <地址>`，其余步骤不变。
> 归档解压后会多一层 `wireless-main/` 目录，所以命令里用 `*/scripts/install.sh` 通配，不必关心目录名。

### 方法二：手动安装

<details>
<summary>点击展开手动安装步骤</summary>

```bash
# 1. 下载并解包（不需要 git）
wget -O /tmp/wx.tar.gz https://gitee.com/okuni/wireless/repository/archive/main.tar.gz
mkdir -p /tmp/wx-install
tar -xzf /tmp/wx.tar.gz -C /tmp/wx-install

# 2. 进入解包后的目录（目录名形如 wireless-main）
cd /tmp/wx-install/*/

# 3. 复制文件
mkdir -p /www/wx /www/cgi-bin /usr/libexec/rpcd /usr/share/rpcd/acl.d /etc/wx
cp -r wx/* /www/wx/
cp wx/.ver /www/wx/
cp -r cgi-bin/* /www/cgi-bin/
cp rpcd/wx-wireless /usr/libexec/rpcd/
cp acl.d/* /usr/share/rpcd/acl.d/
cp etc/wx/wifi-config.json /etc/wx/
cp etc/wx/wx_settings.conf /etc/wx/

# 4. 设置权限 & 转换换行符
chmod +x /www/cgi-bin/*.sh /usr/libexec/rpcd/wx-wireless
sed -i 's/\r$//' /www/cgi-bin/*.sh /usr/libexec/rpcd/wx-wireless

# 5. 重启服务
/etc/init.d/rpcd restart && /etc/init.d/uhttpd restart

# 6. 清理
cd / && rm -rf /tmp/wx-install /tmp/wx.tar.gz
```

</details>

## 卸载方法

### 一键卸载

```bash
# 直接执行已安装的卸载脚本
sh /etc/wx/uninstall.sh
```

> ⚠️ **警告**：卸载操作将完全移除 WiFi Manager 及其所有相关文件，包括配置文件和日志。

> 💡 **说明**：卸载脚本在安装时已复制到 `/etc/wx/uninstall.sh`，无需重新克隆仓库。

## 访问地址

安装完成后，通过浏览器访问：

```
http://<路由器IP>/wx/
```

首次使用需要设置管理密码。

## 系统要求

- OpenWrt 21.02 或更高版本
- 已安装 `uhttpd`（通常已预装）
- 已安装 `rpcd`（通常已预装）
- 下载工具任一即可：`curl` / `wget` / `uclient-fetch`（OpenWrt 至少自带一个）
- **不需要 git**：安装和 OTA 更新都改用 HTTP 下载 tar.gz 归档

## OTA 更新

系统支持在线检查和更新：

1. 进入「系统状态」页面
2. 点击「系统更新」
3. 点击「检查更新」
4. 如有新版本，点击「立即更新」

实现方式（`cgi-bin/wx-auth.sh`）：

- 版本列表取自 Gitee OpenAPI：`https://gitee.com/api/v5/repos/okuni/wireless/tags`
- 更新包下载地址：`https://gitee.com/okuni/wireless/repository/archive/<tag>.tar.gz`
- 解包后调用包内的 `scripts/install.sh` 完成覆盖安装（异步执行，因为该脚本会重启 uhttpd）
- 取不到版本列表时返回错误提示，不会误报「已是最新版本」

## 版本历史

版本号存储在 `/www/wx/.ver` 文件中，由发布脚本 `scripts/build-vue.ps1` 写入（形如 `V3.0`）。
与 Gitee tag（形如 `v3.0`）比较时会忽略 `v`/`V` 前缀和大小写，两种写法都能正确判断。

## 许可证

MIT License

## 问题反馈

如有问题，请在 Gitee 提交 Issue。
