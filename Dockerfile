FROM alpine:3.19

RUN apk add --no-cache openssh && \
    mkdir -p /var/empty && chmod 755 /var/empty && \
    addgroup -S tunnel && \
    adduser -S -G tunnel -D -h /home/pg-tunnel -s /bin/false pg-tunnel && \
    # 解锁账户（密码认证已禁用，但 sshd 拒绝 locked 账户）
    sed -i 's/^pg-tunnel:!:pg-tunnel:*:/' /etc/shadow && \
    mkdir -p /home/pg-tunnel/.ssh && \
    chown pg-tunnel:tunnel /home/pg-tunnel /home/pg-tunnel/.ssh && \
    chmod 700 /home/pg-tunnel/.ssh

COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
