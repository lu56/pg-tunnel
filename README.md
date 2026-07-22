---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '2db7b1c8-9713-4629-9974-c3fcec436af5'
  PropagateID: '2db7b1c8-9713-4629-9974-c3fcec436af5'
  ReservedCode1: '8d678729-dd90-4b83-b3f2-0d13db8fe8d6'
  ReservedCode2: '8d678729-dd90-4b83-b3f2-0d13db8fe8d6'
---

# pg-tunnel

SSH 隧道容器 — 专为 PostgreSQL 安全转发设计。

## 使用

```bash
# 拉取镜像
docker pull viplu56/pg-tunnel:latest

# 运行
docker run -d --name pg-tunnel --network host \
  -e TUNNEL_PUBLIC_KEY="ssh-ed25519 AAAA... pg-tunnel" \
  -e SSH_PORT=2222 \
  -e PG_HOST=localhost \
  -e PG_PORT=15432 \
  -v ./host_keys:/etc/ssh/host_keys \
  --restart unless-stopped \
  viplu56/pg-tunnel:latest
```

或用 docker-compose：

```bash
cp .env.example .env
# 编辑 .env 填入公钥
docker-compose up -d
```

## 环境变量

| 变量 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| `TUNNEL_PUBLIC_KEY` | 是 | — | SSH 公钥，写入 authorized_keys |
| `SSH_PORT` | 否 | `2222` | sshd 监听端口（host 模式下=宿主机端口） |
| `PG_HOST` | 否 | `localhost` | PermitOpen 目标主机 |
| `PG_PORT` | 否 | `15432` | PermitOpen 目标端口 |

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
| 空闲超时 | 5 分钟无活动自动断开（ClientAliveInterval=300） |
| 私钥安全 | 私钥不在镜像中，仅在客户端；公钥通过环境变量注入 |
| host keys | 持久化在 volume 中，容器重建不变；不入 Git |

## 文件

| 文件 | 说明 |
|------|------|
| Dockerfile | Alpine + openssh，创建受限用户 |
| sshd_config | sshd 配置，占位符运行时替换 |
| entrypoint.sh | 生成 host keys，写入 authorized_keys，替换配置，启动 sshd |
| docker-compose.yml | host 网络模式，环境变量注入 |
| .env.example | 环境变量模板 |

> AI生成