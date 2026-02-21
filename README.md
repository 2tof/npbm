推荐使用新的脚本安装：
https://github.com/2tof/npMan

# NodePass 端口转发服务脚本使用说明

## 简介

这是一个用于管理 NodePass 端口转发服务的 Bash 脚本。该脚本支持通过 INI 格式的配置文件来指定服务器和客户端端口，并提供日志级别和日志文件位置的配置选项。脚本还支持作为守护进程运行，并可以设置为系统启动时自动运行。新增功能：自动下载和安装 NodePass 最新版本。

## 二进制文件来自于NodePass项目的发布页：
https://github.com/yosebyte/nodepass/tree/main
其他高级用法也请参见nodepass原版的说明及更新；
此脚本仅为方便下载、运行和管理nodepass可执行文件，安装服务和调用配置文件config.ini；

## 前提条件

- Debian 或其他常见 Linux 发行版
- 具有 sudo 权限（用于安装系统服务和二进制文件）
- 网络连接（用于自动下载 NodePass）

## 配置文件

配置文件使用 INI 格式，默认路径为 `/etc/nodepass/config.ini`。配置文件示例：

```ini
[general]
mode = server

[server]
host = 0.0.0.0
port = 10101

[client]
host = 127.0.0.1
port = 8080

[security]
tls_mode = 1

[logging]
level = debug
file = /var/log/nodepass.log
```

### 配置选项说明

- **[general]**
  - `mode`: 运行模式，可选值为 `server`、`client` 或 `master`

- **[server]**
  - `host`: 服务器主机地址，默认为 `0.0.0.0`
  - `port`: 服务器端口，默认为 `10101`

- **[client]**
  - `host`: 客户端主机地址，默认为 `127.0.0.1`
  - `port`: 客户端端口，默认为 `8080`

- **[security]**
  - `tls_mode`: TLS 安全模式，可选值为 `0`（无加密）、`1`（自签名证书）或 `2`（自定义证书验证）

- **[logging]**
  - `level`: 日志级别，可选值为 `debug`、`info`、`warn` 或 `error`
  - `file`: 日志文件路径

## 使用方法

### 基本命令

```bash
./nodepass_service.sh {start|stop|restart|status|install|update} [config_file]
```

### 命令说明

- `start`: 启动 NodePass 服务
- `stop`: 停止 NodePass 服务
- `restart`: 重启 NodePass 服务
- `status`: 检查 NodePass 服务状态
- `install`: 将 NodePass 安装为系统服务
- `update`: 下载并安装最新版本的 NodePass 二进制文件

### 选项

- `config_file`: 配置文件路径（可选，默认为 `/etc/nodepass/config.ini`）

### 示例

1. 下载并安装最新版本的 NodePass：
   ```bash
   ./nodepass_service.sh update
   ```

2. 使用默认配置文件启动服务：
   ```bash
   ./nodepass_service.sh start
   ```

3. 使用自定义配置文件启动服务：
   ```bash
   ./nodepass_service.sh start /path/to/custom_config.ini
   ```

4. 检查服务状态：
   ```bash
   ./nodepass_service.sh status
   ```

5. 安装为系统服务：
   ```bash
   sudo ./nodepass_service.sh install
   ```

## 安装为系统服务

执行以下命令将 NodePass 安装为系统服务：

```bash
sudo ./nodepass_service.sh install
```

安装后，可以使用以下命令管理服务：

- 启动服务：`sudo systemctl start nodepass`
- 停止服务：`sudo systemctl stop nodepass`
- 重启服务：`sudo systemctl restart nodepass`
- 查看状态：`sudo systemctl status nodepass`
- 启用自启动：`sudo systemctl enable nodepass`
- 禁用自启动：`sudo systemctl disable nodepass`

## 自动下载和更新

脚本包含自动下载和安装最新版本 NodePass 的功能。执行以下命令可以更新 NodePass：

```bash
./nodepass_service.sh update
```

此命令会：
1. 检测系统架构
2. 从 GitHub 获取最新版本（包括预发布版本）
3. 下载适合当前系统的二进制包
4. 解压并安装到 `/usr/local/bin/nodepass`

如果在启动服务时检测到 NodePass 二进制文件不存在，脚本会自动尝试下载和安装最新版本。

## 日志

服务日志将写入配置文件中指定的日志文件。默认日志文件路径为 `/var/log/nodepass.log`。

## 故障排除

1. 如果服务无法启动，请检查：
   - NodePass 是否已正确安装
   - 配置文件是否存在且格式正确
   - 指定的端口是否已被占用

2. 如果自动下载失败，请检查：
   - 网络连接是否正常
   - GitHub API 是否可访问
   - 是否有足够的权限写入目标目录

3. 如果服务启动后无法正常工作，请检查日志文件以获取详细错误信息。

4. 如果 PID 文件存在但服务未运行，可以使用 `restart` 命令重新启动服务。
