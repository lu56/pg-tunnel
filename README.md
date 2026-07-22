---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '1f11e03c-d362-487d-a561-ad407fd193d6'
  PropagateID: '1f11e03c-d362-487d-a561-ad407fd193d6'
  ReservedCode1: 'd9bb2ed6-7115-4359-aa58-4f48a24be53e'
  ReservedCode2: 'd9bb2ed6-7115-4359-aa58-4f48a24be53e'
---

# pg-tunnel

SSH 隧道容器 — 专为 PostgreSQL 安全转发设计。

## 快速开始

```bash
# 1. 创建目录
mkdir -p /volume1/docker/pg-tunnel/{host_keys,keys}
cd /volume1/docker/pg-tunnel

# 2. 创建 .env（最小配置，不需要填公钥）
cat > .env << 'EOF'
SSH_PORT=2222
PG_HOST=localhost
PG_PORT=15432
EOF

# 3. 运行
docker run -d --name pg-tunnel --network host \
  --env-file .env \
  -v ./host_keys:/etc/ssh/host_keys \
  -v ./keys:/keys \
  --restart unless-stopped \
  viplu56/pg-tunnel:latest

# 4. 查看日志，确认密钥自动生成
docker logs pg-tunnel

# 5. 取走私钥（复制到 Windows 设备供 VB.NET 工具使用）
cat ./keys/pg_tunnel_ed25519
```

首次启动时容器会自动生成密钥对，日志中会提示私钥位置。将私钥拷到 Windows 设备后，可以删除服务器上的私钥副本：

```bash
rm ./keys/pg_tunnel_ed25519
# 公钥保留，容器重启后会自动用公钥配置 authorized_keys
```

## 密钥管理

### 自动模式（默认）

不填 `TUNNEL_PUBLIC_KEY`，容器首次启动自动生成：
- 私钥：`./keys/pg_tunnel_ed25519` → 拷到 Windows 设备
- 公钥：`./keys/pg_tunnel_ed25519.pub` → 容器自动用

### 手动模式

在 `.env` 中填入 `TUNNEL_PUBLIC_KEY`，容器使用你指定的公钥，不自动生成。

### 轮换密钥

```bash
# 删除旧密钥，重启容器即可自动生成新密钥
rm ./keys/pg_tunnel_ed25519 ./keys/pg_tunnel_ed25519.pub
docker restart pg-tunnel
# 拷走新私钥，分发到各设备
```

## 环境变量

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `TUNNEL_PUBLIC_KEY` | 否 | 自动生成 | SSH 公钥，不填则容器自动生成密钥对 |
| `SSH_PORT` | 否 | `2222` | sshd 监听端口（host 模式下=宿主机端口） |
| `PG_HOST` | 否 | `localhost` | PermitOpen 目标主机 |
| `PG_PORT` | 否 | `15432` | PermitOpen 目标端口 |

## docker-compose 运行

```bash
cp .env.example .env
# 编辑 .env（最小配置不需要改，默认自动生成密钥）
docker-compose up -d
```

## 镜像构建

镜像通过 GitHub Actions 自动构建并推送到 Docker Hub。

push 到 `main` 分支 → 自动构建 `latest` + commit sha 标签
push tag `v*` → 自动构建版本号标签（如 `v1.0.0`）

### 平台

镜像支持 `linux/amd64` + `linux/arm64`，群晖 ARM 机型也可直接拉取。

## 安全模型

| 维度 | 措施 |
|------|------|
| 认证 | 密钥认证 only，禁用密码和键盘交互 |
| 用户隔离 | pg-tunnel 用户 shell=/bin/false，AllowUsers 限制 |
| 转发锁定 | PermitOpen only PG_HOST:PG_PORT，AllowTcpForwarding local |
| 其他全关 | X11/TTY/GatewayPorts/AgentForwarding/StreamLocal 全部禁止 |
| 加密套件 | 仅 curve25519/chacha20/aes-gcm，拒绝弱算法 |
| 私钥安全 | 私钥不在镜像中，仅在客户端；自动生成时存在 keys/ volume 供取走 |
| host keys | 持久化在 volume 中，容器重建不变；不入 Git |

## 文件

| 文件 | 说明 |
|------|------|
| Dockerfile | Alpine + openssh，创建受限用户 |
| sshd_config | sshd 配置，占位符运行时替换 |
| entrypoint.sh | 生成 host keys + 隧道密钥对，写入 authorized_keys，启动 sshd |
| docker-compose.yml | host 网络模式，环境变量注入，双 volume |
| .env.example | 环境变量模板 |

> AI生成