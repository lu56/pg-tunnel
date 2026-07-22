#!/bin/sh
set -e

HOST_KEY_DIR="/etc/ssh/host_keys"
mkdir -p "$HOST_KEY_DIR"

# 生成 host keys（持久化在 volume 中，容器重建不丢失）
if [ ! -f "$HOST_KEY_DIR/ssh_host_ed25519_key" ]; then
    ssh-keygen -t ed25519 -f "$HOST_KEY_DIR/ssh_host_ed25519_key" -N '' -q
fi
if [ ! -f "$HOST_KEY_DIR/ssh_host_rsa_key" ]; then
    ssh-keygen -t rsa -b 4096 -f "$HOST_KEY_DIR/ssh_host_rsa_key" -N '' -q
fi
chmod 600 "$HOST_KEY_DIR"/*

# 写入或更新 authorized_keys
AUTH_KEYS="/home/pg-tunnel/.ssh/authorized_keys"
if [ -n "$TUNNEL_PUBLIC_KEY" ]; then
    echo "$TUNNEL_PUBLIC_KEY" > "$AUTH_KEYS"
elif [ ! -f "$AUTH_KEYS" ]; then
    echo "ERROR: 请设置 TUNNEL_PUBLIC_KEY 环境变量或挂载 authorized_keys 文件"
    exit 1
fi
chown pg-tunnel:tunnel "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

# 从环境变量读取配置，有默认值
SSH_PORT="${SSH_PORT:-2222}"
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-15432}"

# 运行时替换 sshd_config 中的占位符
sed -i \
    -e "s/__SSH_PORT__/${SSH_PORT}/" \
    -e "s/__PG_HOST__/${PG_HOST}/" \
    -e "s/__PG_PORT__/${PG_PORT}/" \
    /etc/ssh/sshd_config

# 校验配置
/usr/sbin/sshd -t

# 前台运行 sshd
exec /usr/sbin/sshd -D -e
