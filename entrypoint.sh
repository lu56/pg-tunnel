#!/bin/sh
set -e

TUNNEL_KEY_DIR="/keys"
HOST_KEY_DIR="/etc/ssh/host_keys"
mkdir -p "$TUNNEL_KEY_DIR" "$HOST_KEY_DIR"

# ============================================================
# 1. SSH host keys（服务器身份证书，持久化在 volume 中）
# ============================================================
if [ ! -f "$HOST_KEY_DIR/ssh_host_ed25519_key" ]; then
    echo "[pg-tunnel] Generating SSH host keys..."
    ssh-keygen -t ed25519 -f "$HOST_KEY_DIR/ssh_host_ed25519_key" -N '' -q
    ssh-keygen -t rsa -b 4096 -f "$HOST_KEY_DIR/ssh_host_rsa_key" -N '' -q
fi
chmod 600 "$HOST_KEY_DIR"/*

# ============================================================
# 2. 隧道密钥对（客户端连接用）
#    - 如果 TUNNEL_PUBLIC_KEY 环境变量已设置 → 用指定的公钥
#    - 否则如果 /keys/pg_tunnel_ed25519 已存在 → 用已有的
#    - 否则自动生成一对，私钥和公钥都写到 /keys/
# ============================================================
PRIVATE_KEY="$TUNNEL_KEY_DIR/pg_tunnel_ed25519"
PUBLIC_KEY="${PRIVATE_KEY}.pub"
AUTH_KEYS="/home/pg-tunnel/.ssh/authorized_keys"

if [ -n "$TUNNEL_PUBLIC_KEY" ]; then
    # 模式 A：用户指定公钥
    echo "[pg-tunnel] Using TUNNEL_PUBLIC_KEY from environment"
    echo "$TUNNEL_PUBLIC_KEY" > "$AUTH_KEYS"
elif [ -f "$PUBLIC_KEY" ]; then
    # 模式 B：已有自动生成的密钥对
    echo "[pg-tunnel] Using existing tunnel key pair from /keys/"
    cp "$PUBLIC_KEY" "$AUTH_KEYS"
else
    # 模式 C：首次启动，自动生成
    echo "[pg-tunnel] Auto-generating tunnel key pair..."
    ssh-keygen -t ed25519 -f "$PRIVATE_KEY" -N '' -q -C "pg-tunnel"
    chmod 600 "$PRIVATE_KEY"
    chmod 644 "$PUBLIC_KEY"
    cp "$PUBLIC_KEY" "$AUTH_KEYS"
    echo "[pg-tunnel] ============================================"
    echo "[pg-tunnel]  Tunnel key pair generated at:"
    echo "[pg-tunnel]    $PRIVATE_KEY (private)"
    echo "[pg-tunnel]    $PUBLIC_KEY (public)"
    echo "[pg-tunnel]  Copy the private key to your Windows devices."
    echo "[pg-tunnel]  After copying, you may delete it from the server."
    echo "[pg-tunnel] ============================================"
fi
chown pg-tunnel:tunnel "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

# ============================================================
# 3. 环境变量配置（运行时替换 sshd_config 占位符）
# ============================================================
SSH_PORT="${SSH_PORT:-2222}"
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-15432}"

sed -i \
    -e "s/__SSH_PORT__/${SSH_PORT}/" \
    -e "s/__PG_HOST__/${PG_HOST}/" \
    -e "s/__PG_PORT__/${PG_PORT}/" \
    /etc/ssh/sshd_config

# ============================================================
# 4. 校验并启动
# ============================================================
/usr/sbin/sshd -t
echo "[pg-tunnel] sshd listening on port $SSH_PORT, forwarding to $PG_HOST:$PG_PORT"
exec /usr/sbin/sshd -D -e
