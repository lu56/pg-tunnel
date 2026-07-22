---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '5aa2e6cb-d4f6-421b-9c9d-d6a207a98fef'
  PropagateID: '5aa2e6cb-d4f6-421b-9c9d-d6a207a98fef'
  ReservedCode1: '89dd4a52-150d-4277-8a2d-32d03b9d73a0'
  ReservedCode2: '89dd4a52-150d-4277-8a2d-32d03b9d73a0'
---

# pg-tunnel

SSH 隧道容器 — 专为 PostgreSQL 安全转发设计。

## 使用

```bash
# 拉取镜像
docker pull <你的DockerHub用户名>/pg-tunnel:latest

# 运行
docker run -d --name pg-tunnel --network host \
  -e TUNNEL_PUBLIC_KEY="ssh-ed25519 AAAA... pg-tunnel" \
  -v ./host_keys:/etc/ssh/host_keys \
  --restart unless-stopped \
  <你的DockerHub用户名>/pg-tunnel:latest
```

或用 docker-compose（参见 `docker-compose.yml`）：

```bash
cp .env.example .env
# 编辑 .env 填入公钥
docker-compose up -d
```

## 镜像构建

镜像通过 GitHub Actions 自动构建并推送到 Docker Hub。

push 到 `main` 分支 → 自动构建 `latest` + commit sha 标签
push tag `v*` → 自动构建版本号标签（如 `v1.0.0`）

### 首次配置

1. GitHub 新建仓库 `pg-tunnel`，push 代码
2. Docker Hub 新建仓库 `pg-tunnel`
3. Docker Hub → Account Settings → Security → New Access Token，复制 token
4. GitHub 仓库 → Settings → Secrets and variables → Actions → 添加：
   - `DOCKERHUB_USERNAME` — Docker Hub 用户名
   - `DOCKERHUB_TOKEN` — 上一步的 Access Token
5. push 到 main 即自动触发构建

### 平台

镜像支持 `linux/amd64` + `linux/arm64`，群晖 ARM 机型也可直接拉取。

## 配置

创建 `.env`（从 `.env.example` 复制），填入公钥：

```
TUNNEL_PUBLIC_KEY=ssh-ed25519 你的公钥内容 pg-tunnel
```

生成密钥：
```bash
ssh-keygen -t ed25519 -f pg_tunnel_ed25519 -C "pg-tunnel"
```

## 安全模型

- 密钥认证 only，禁用密码
- 用户 `pg-tunnel`，shell=/bin/false，无法交互登录
- `PermitOpen localhost:15432` — 只能转发到 PG
- `AllowTcpForwarding local` — 仅本地转发，禁止远程转发
- X11/TTY/GatewayPorts/AgentForwarding 全部关闭

## 文件

| 文件 | 说明 |
|------|------|
| Dockerfile | Alpine + openssh，创建受限用户 |
| sshd_config | sshd 配置，Match 块锁定隧道权限 |
| entrypoint.sh | 生成 host keys，写入 authorized_keys，启动 sshd |
| docker-compose.yml | host 网络模式，.env 注入公钥 |
| .env.example | 环境变量模板 |

> AI生成