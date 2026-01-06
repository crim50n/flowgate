#!/bin/bash
set -e

# PID tracking
DNS_PID=""
PROXY_PID=""
WEB_PID=""
SHUTDOWN=0

# Graceful shutdown handler
cleanup() {
    if [ "$SHUTDOWN" -eq 1 ]; then
        return
    fi
    SHUTDOWN=1
    echo ""
    echo "[Flowgate] Shutting down services..."

    # Stop Web UI first
    if [ -n "$WEB_PID" ] && kill -0 "$WEB_PID" 2>/dev/null; then
        echo "[Flowgate] Stopping Flowgate Web (PID $WEB_PID)..."
        kill -TERM "$WEB_PID" 2>/dev/null || true
    fi

    # Stop Proxy
    if [ -n "$PROXY_PID" ] && kill -0 "$PROXY_PID" 2>/dev/null; then
        echo "[Flowgate] Stopping $PROXY_NAME (PID $PROXY_PID)..."
        kill -TERM "$PROXY_PID" 2>/dev/null || true
    fi

    # Stop DNS
    if [ -n "$DNS_PID" ] && kill -0 "$DNS_PID" 2>/dev/null; then
        echo "[Flowgate] Stopping $DNS_NAME (PID $DNS_PID)..."
        kill -TERM "$DNS_PID" 2>/dev/null || true
    fi

    # Wait for processes to exit
    sleep 2
    echo "[Flowgate] All services stopped."
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT EXIT

# Detect Software
if command -v angie >/dev/null 2>&1; then
    PROXY_BIN="angie"
    PROXY_NAME="Angie"
elif command -v nginx >/dev/null 2>&1; then
    PROXY_BIN="nginx"
    PROXY_NAME="Nginx"
else
    echo "[Flowgate] ERROR: No proxy server found (angie/nginx)"
    exit 1
fi

if [ -f "/usr/local/bin/AdGuardHome" ]; then
    DNS_BIN="/usr/local/bin/AdGuardHome"
    DNS_NAME="AdGuardHome"
    DNS_ARGS="-w /opt/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --no-check-update"
elif [ -f "/opt/AdGuardHome/AdGuardHome" ]; then
    DNS_BIN="/opt/AdGuardHome/AdGuardHome"
    DNS_NAME="AdGuardHome"
    DNS_ARGS="-w /opt/AdGuardHome -c /opt/AdGuardHome/AdGuardHome.yaml --no-check-update"
elif command -v blocky >/dev/null 2>&1; then
    DNS_BIN="blocky"
    DNS_NAME="Blocky"
    DNS_ARGS="--config /etc/blocky/config.yml"
else
    echo "[Flowgate] ERROR: No DNS server found (AdGuardHome/blocky)"
    exit 1
fi

# 1. Initialize Config
if [ ! -f /etc/flowgate/flowgate.yaml ]; then
    echo "[Flowgate] Initializing configuration..."
    cp /etc/flowgate/flowgate.yaml.default /etc/flowgate/flowgate.yaml

    # Detect Public IP if set to auto
    if [ "$PROXY_IP" = "auto" ]; then
        PUBLIC_IP=$(curl -sf --connect-timeout 5 https://api.ipify.org || curl -sf --connect-timeout 5 https://ifconfig.me || echo "127.0.0.1")
        echo "[Flowgate] Detected Public IP: $PUBLIC_IP"
    else
        PUBLIC_IP="$PROXY_IP"
        echo "[Flowgate] Using configured IP: $PUBLIC_IP"
    fi

    # Update IP in config
    sed -i "s/proxy_ip: .*/proxy_ip: \"$PUBLIC_IP\"/" /etc/flowgate/flowgate.yaml

    # Set DNS Domain if provided via ENV
    if [ -n "$DNS_DOMAIN" ]; then
        echo "[Flowgate] Setting primary DNS domain: $DNS_DOMAIN"
        /usr/bin/flowgate dns "$DNS_DOMAIN"
    fi
fi

# 2. Generate Initial Configs
echo "[Flowgate] Generating service configurations..."
# Ensure directories exist
if [ "$PROXY_NAME" = "Angie" ]; then
    mkdir -p /etc/angie/stream.d /etc/angie/http.d /run/angie
else
    mkdir -p /etc/nginx/streams-enabled /etc/nginx/sites-enabled /run/nginx
    # Ensure nginx user directive is correct
    if grep -q "^user www-data" /etc/nginx/nginx.conf 2>/dev/null && ! id -u www-data >/dev/null 2>&1; then
        if id -u nginx >/dev/null 2>&1; then
            sed -i 's/^user www-data/user nginx/' /etc/nginx/nginx.conf
            echo "[Flowgate] Fixed nginx user to 'nginx'"
        fi
    elif grep -q "^user nginx" /etc/nginx/nginx.conf 2>/dev/null && ! id -u nginx >/dev/null 2>&1; then
        if id -u www-data >/dev/null 2>&1; then
            sed -i 's/^user nginx/user www-data/' /etc/nginx/nginx.conf
            echo "[Flowgate] Fixed nginx user to 'www-data'"
        fi
    fi
fi

# Ensure snakeoil certificate exists (for HTTPS fallback)
if [ ! -f /etc/ssl/certs/ssl-cert-snakeoil.pem ] || [ ! -f /etc/ssl/private/ssl-cert-snakeoil.key ]; then
    echo "[Flowgate] Generating snakeoil SSL certificate..."
    mkdir -p /etc/ssl/certs /etc/ssl/private
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/ssl/private/ssl-cert-snakeoil.key \
        -out /etc/ssl/certs/ssl-cert-snakeoil.pem \
        -subj '/CN=localhost/O=Flowgate/C=XX' 2>/dev/null
fi

# Ensure DNS config exists
if [ "$DNS_NAME" = "Blocky" ]; then
    mkdir -p /etc/blocky
    if [ ! -f /etc/blocky/config.yml ]; then
        echo "[Flowgate] Creating default Blocky config..."
        cat > /etc/blocky/config.yml << 'BLOCKY_EOF'
upstreams:
  groups:
    default:
      - https://8.8.8.8/dns-query
      - https://1.1.1.1/dns-query

ports:
  dns: 53
  tls: 853

blocking:
  denylists:
    ads:
      - https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
  clientGroupsBlock:
    default:
      - ads

log:
  level: info
  format: text
BLOCKY_EOF
    fi
fi

# Run sync to generate configs
/usr/bin/flowgate sync || echo "[Flowgate] Sync completed with warnings"

# 3. Start Services
echo "[Flowgate] Starting $DNS_NAME..."
if [ "$DNS_NAME" = "Blocky" ]; then
    if id -u blocky >/dev/null 2>&1; then
        su -s /bin/sh -c "$DNS_BIN $DNS_ARGS" blocky &
    else
        $DNS_BIN $DNS_ARGS &
    fi
else
    # AdGuardHome
    if id -u adguardhome >/dev/null 2>&1; then
        su -s /bin/sh -c "$DNS_BIN $DNS_ARGS" adguardhome &
    else
        $DNS_BIN $DNS_ARGS &
    fi
fi
DNS_PID=$!
echo "[Flowgate] $DNS_NAME started with PID $DNS_PID"

# Wait for DNS to be ready
sleep 2

echo "[Flowgate] Starting $PROXY_NAME..."
$PROXY_BIN -g 'daemon off;' &
PROXY_PID=$!
echo "[Flowgate] $PROXY_NAME started with PID $PROXY_PID"

# Display Startup Banner
echo ""
echo "========================================================================"
echo "   Flowgate - Network Flow Controller"
echo "========================================================================"
echo " Services Started:"
echo "   - DNS ($DNS_NAME):    Port 53 (UDP/TCP), 853 (DoT)"
echo "   - Proxy ($PROXY_NAME):  Port 80/443"

if [ "$ENABLE_WEB_UI" = "true" ]; then
    echo "[Flowgate] Starting Flowgate Web..."
    cd /usr/share/flowgate
    if id -u flowgate >/dev/null 2>&1; then
        su -s /bin/sh -c "uvicorn main:app --host 0.0.0.0 --port 5000 --log-level warning" flowgate &
    else
        uvicorn main:app --host 0.0.0.0 --port 5000 --log-level warning &
    fi
    WEB_PID=$!
    echo "[Flowgate] Flowgate Web started with PID $WEB_PID"
    echo "   - Web UI:           Port 5000"
else
    echo "   - Web UI:           Disabled (ENABLE_WEB_UI=false)"
fi

echo "========================================================================"
echo ""

# Wait for any process to exit
while true; do
    # Check if main processes are still running
    if [ -n "$DNS_PID" ] && ! kill -0 "$DNS_PID" 2>/dev/null; then
        echo "[Flowgate] ERROR: $DNS_NAME (PID $DNS_PID) has stopped unexpectedly"
        exit 1
    fi
    if [ -n "$PROXY_PID" ] && ! kill -0 "$PROXY_PID" 2>/dev/null; then
        echo "[Flowgate] ERROR: $PROXY_NAME (PID $PROXY_PID) has stopped unexpectedly"
        exit 1
    fi
    if [ "$ENABLE_WEB_UI" = "true" ] && [ -n "$WEB_PID" ] && ! kill -0 "$WEB_PID" 2>/dev/null; then
        echo "[Flowgate] WARNING: Flowgate Web (PID $WEB_PID) has stopped"
        # Web UI is not critical, just log warning
    fi
    sleep 5
done
