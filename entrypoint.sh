#!/bin/bash
set -e

# Generate SSH host keys on first run (not baked into image)
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi

# Copy authorized keys if mounted
if [ -f /tmp/authorized_keys ]; then
    cp /tmp/authorized_keys /home/dev/.ssh/authorized_keys
    chown dev:dev /home/dev/.ssh/authorized_keys
    chmod 600 /home/dev/.ssh/authorized_keys
    echo "✓ SSH keys configured"
fi

# Wire up the egress-allowlisting proxy sidecar for SSH sessions. The
# sidecar's IP isn't stable across `container stop`/`start` (Apple's
# `container` runtime has no static-IP option), so the Makefile writes its
# current address to a bind-mounted file on every start rather than baking
# it into a container env var at creation time. sshd's PAM session doesn't
# inherit the container process's environment either way, so this has to
# land in /etc/environment for every login to pick it up. Re-derive it fresh
# each boot (strip any stale lines first) since this runs on every
# `container start`, not just the first `run`.
PROXY_IP_FILE=/etc/copilot-sandbox/proxy-ip
if [ -f "$PROXY_IP_FILE" ]; then
    PROXY_IP=$(cat "$PROXY_IP_FILE")
    PROXY_PORT=8888 # keep in sync with proxy/tinyproxy.conf's Port and the Makefile's PROXY_PORT
    sed -i '/^\(HTTP_PROXY\|HTTPS_PROXY\|NO_PROXY\)=/d' /etc/environment
    {
        echo "HTTP_PROXY=http://$PROXY_IP:$PROXY_PORT"
        echo "HTTPS_PROXY=http://$PROXY_IP:$PROXY_PORT"
        echo "NO_PROXY=localhost,127.0.0.1"
    } >> /etc/environment
fi

# Create keyring initialization script for SSH login sessions
cat > /etc/profile.d/keyring.sh << 'KEYRING'
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    eval $(echo '' | gnome-keyring-daemon --unlock --components=secrets 2>/dev/null)
fi
KEYRING
chmod +x /etc/profile.d/keyring.sh

echo "✓ SSH server starting on port 22"
echo "  Connect with: ssh -p 2222 dev@localhost"

# Run sshd in foreground
exec /usr/sbin/sshd -D
