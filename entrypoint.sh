#!/bin/bash
set -e

# Graceful shutdown handler
cleanup() {
    echo "Shutting down services..."
    [ -n "$WEB_PID" ] && kill -TERM "$WEB_PID" 2>/dev/null
    [ -n "$PROXY_PID" ] && kill -TERM "$PROXY_PID" 2>/dev/null
    [ -n "$DNS_PID" ] && kill -TERM "$DNS_PID" 2>/dev/null
    wait
    echo "All services stopped."
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

# Detect Software
if command -v angie >/dev/null 2>&1; then
    PROXY_BIN="angie"
    PROXY_NAME="Angie"
else
    PROXY_BIN="nginx"
    PROXY_NAME="Nginx"
fi

if [ -f "/usr/local/bin/AdGuardHome" ]; then
    DNS_BIN="/usr/local/bin/AdGuardHome"
    DNS_NAME="AdGuardHome"
    DNS_ARGS="-w /opt/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --no-check-update"
elif [ -f "/opt/AdGuardHome/AdGuardHome" ]; then
    DNS_BIN="/opt/AdGuardHome/AdGuardHome"
    DNS_NAME="AdGuardHome"
    DNS_ARGS="-w /opt/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --no-check-update"
else
    DNS_BIN="blocky"
    DNS_NAME="Blocky"
    DNS_ARGS="--config /etc/blocky/config.yml"
fi

# 1. Initialize Config
if [ ! -f /etc/flowgate/flowgate.yaml ]; then
    echo "Initializing configuration..."
    cp /etc/flowgate/flowgate.yaml.default /etc/flowgate/flowgate.yaml

    # Detect Public IP if set to auto
    if [ "$PROXY_IP" = "auto" ]; then
        PUBLIC_IP=$(curl -s https://api.ipify.org)
        echo "Detected Public IP: $PUBLIC_IP"
    else
        PUBLIC_IP="$PROXY_IP"
        echo "Using configured IP: $PUBLIC_IP"
    fi

    # Update IP in config
    sed -i "s/proxy_ip: .*/proxy_ip: \"$PUBLIC_IP\"/" /etc/flowgate/flowgate.yaml

    # Set DNS Domain if provided via ENV
    if [ ! -z "$DNS_DOMAIN" ]; then
        echo "Setting primary DNS domain: $DNS_DOMAIN"
        /usr/bin/flowgate dns "$DNS_DOMAIN"
    fi
fi

# 2. Generate Initial Configs
echo "Generating service configurations..."
# Ensure directories exist
if [ "$PROXY_NAME" = "Angie" ]; then
    mkdir -p /etc/angie/stream.d /etc/angie/http.d
else
    mkdir -p /etc/nginx/streams-enabled /etc/nginx/sites-enabled
fi

# Run sync to generate configs
/usr/bin/flowgate sync || true

# 3. Start Services
echo "Starting $DNS_NAME..."
if [ "$DNS_NAME" = "Blocky" ]; then
    if id -u blocky >/dev/null 2>&1; then
        su -s /bin/bash -c "$DNS_BIN $DNS_ARGS" blocky &
    else
        $DNS_BIN $DNS_ARGS &
    fi
else
    # AdGuardHome
    if id -u adguardhome >/dev/null 2>&1; then
        su -s /bin/bash -c "$DNS_BIN $DNS_ARGS" adguardhome &
    else
        $DNS_BIN $DNS_ARGS &
    fi
fi
DNS_PID=$!

echo "Starting $PROXY_NAME..."
$PROXY_BIN -g 'daemon off;' &
PROXY_PID=$!

# Display Startup Banner
echo ""
echo "========================================================================"
echo "   Flowgate - Network Flow Controller"
echo "========================================================================"
echo " Services Started:"
echo "   - DNS ($DNS_NAME):  Port 53 (UDP/TCP), 853 (DoT)"
echo "   - Proxy ($PROXY_NAME): Port 80/443"

if [ "$ENABLE_WEB_UI" = "true" ]; then
    echo "Starting Flowgate Web..."
    cd /usr/share/flowgate
    if id -u flowgate >/dev/null 2>&1; then
        su -s /bin/bash -c "uvicorn main:app --host 0.0.0.0 --port 5000 --log-level info" flowgate &
    else
        uvicorn main:app --host 0.0.0.0 --port 5000 --log-level info &
    fi
    WEB_PID=$!
    wait -n $DNS_PID $PROXY_PID $WEB_PID
else
    echo "   - Web UI:        Disabled (ENABLE_WEB_UI=false)"
    wait -n $DNS_PID $PROXY_PID
fi
