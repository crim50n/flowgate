# Flowgate

**Network Flow Controller (DNS & Proxy Manager)**

Flowgate is a modern CLI tool and Web UI designed to manage your network flow infrastructure. It unifies the configuration of Layer 4/7 proxies (Angie or Nginx) and DNS servers (Blocky or AdGuardHome), making it easy to route traffic, manage local services, and bypass regional restrictions for AI services.

## Features

*   **Unified Management:** Control both your Proxy and DNS server from a single interface.
*   **AI Service Proxying:** Pre-configured list of popular AI services (OpenAI, Google Gemini, Claude, etc.) to easily proxy and bypass restrictions.
*   **Local Service Discovery:** Easily expose local applications via reverse proxy with automatic DNS records.
*   **Web Dashboard:** A user-friendly web interface to manage domains and services.
*   **Automated SSL:** Automatic certificate management via native ACME (for Angie) or Certbot (for Nginx).
*   **Multi-Distribution Support:** Works on 30+ Linux distributions (Debian, Ubuntu, Fedora, Arch, Alpine, openSUSE, Gentoo, Void, and more).
*   **Universal Init System:** Supports systemd, OpenRC, SysVinit, runit, and s6.
*   **Flexible Architecture:** Supports multiple backends:
    *   **Proxy:** Angie or Nginx
    *   **DNS:** Blocky or AdGuardHome

## Installation

Flowgate supports multiple backend combinations. Choose based on your needs:

| Combination | Best For |
|-------------|----------|
| **Angie + Blocky** | Best performance, native ACME SSL, no Certbot needed (default) |
| **Angie + AdGuardHome** | Full-featured: native SSL + DNS Web UI |
| **Nginx + Blocky** | Standard Nginx, uses Certbot for SSL |
| **Nginx + AdGuardHome** | Standard Nginx + Web UI for DNS management |

### Option 1: Debian/Ubuntu (recommended)

Download packages from [Releases](https://github.com/crim50n/flowgate/releases):

**Angie + Blocky (default):**
```bash
# Add Angie repository first (see https://angie.software/en/install/)
sudo apt install ./flowgate_*.deb ./blocky_*.deb angie
sudo flowgate init
```

**Angie + AdGuardHome:**
```bash
# Add Angie repository first (see https://angie.software/en/install/)
sudo apt install ./flowgate_*.deb ./adguardhome_*.deb angie
sudo flowgate init
```

**Nginx + Blocky:**
```bash
sudo apt install ./flowgate_*.deb ./blocky_*.deb
sudo flowgate init
```

**Nginx + AdGuardHome:**
```bash
sudo apt install ./flowgate_*.deb ./adguardhome_*.deb
sudo flowgate init
```

### Option 2: From Source

**Step 1:** Install base dependencies:

```bash
# Debian/Ubuntu
sudo apt install -y python3 python3-yaml

# Fedora/RHEL
sudo dnf install -y python3 python3-pyyaml

# Arch Linux
sudo pacman -S python python-yaml

# Alpine Linux
apk add python3 py3-yaml
```

**Step 2:** Install your chosen Proxy server:

*Angie (no Certbot needed - has native ACME):*
```bash
# See https://angie.software/en/install/ for repository setup
# Debian/Ubuntu
sudo apt install -y angie

# Fedora/RHEL
sudo dnf install -y angie

# Alpine Linux
apk add angie
```

*Nginx:*
```bash
# Debian/Ubuntu
sudo apt install -y nginx libnginx-mod-stream certbot python3-certbot-nginx

# Fedora/RHEL
sudo dnf install -y nginx nginx-mod-stream certbot python3-certbot-nginx

# Arch Linux
sudo pacman -S nginx certbot certbot-nginx

# Alpine Linux
apk add nginx nginx-mod-stream certbot certbot-nginx
```

**Step 3:** Install your chosen DNS server:

*Blocky:*
```bash
# Build from source or download binary from https://github.com/0xERR0R/blocky/releases
sudo cp blocky /usr/bin/
```

*AdGuardHome:*
```bash
# Download from https://github.com/AdguardTeam/AdGuardHome/releases
curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
```

**Step 4:** Install Flowgate:

```bash
sudo make install          # CLI only
sudo make install WEB=1    # CLI + Web UI
```

## Usage

### CLI (`flowgate`)

The `flowgate` command is the primary way to interact with the system.

**Initial Setup:**
```bash
# Initialize Flowgate and apply base configuration
sudo flowgate init
```

**Set Primary DNS Domain (DoH/DoT):**
```bash
sudo flowgate dns dns.mydomain.com
```

**Check Status:**
```bash
sudo flowgate status
```

**Add a Passthrough Proxy (e.g., for AI services):**
```bash
sudo flowgate add example.com
```

**Expose a Local Service (Reverse Proxy):**
```bash
# Maps app.local -> 127.0.0.1:8080
sudo flowgate service app.local 8080

# Maps app.local -> 192.168.1.50:3000
sudo flowgate service app.local 3000 --ip 192.168.1.50
```

**Remove a Domain:**
```bash
sudo flowgate remove example.com
```

**Force Configuration Sync:**
```bash
sudo flowgate sync
```

> **Note:** Commands `add`, `service`, and `dns` automatically run `sync` after changes.

**Service Management:**
```bash
# Start/stop/restart all services
sudo flowgate start
sudo flowgate stop
sudo flowgate restart
```

**System Diagnostics:**
```bash
# Check system status and get installation instructions
sudo flowgate doctor
sudo flowgate doctor -v  # verbose mode
```

**Enable Auto-Sync (recommended):**
```bash
# Automatically sync when /etc/flowgate/flowgate.yaml changes
sudo systemctl enable --now flowgate-sync.path
```

### Web UI

Access the web interface at `http://localhost:5000`

```bash
# Start the service
sudo systemctl start flowgate-web

# Enable on boot
sudo systemctl enable flowgate-web
```

## Configuration

The main configuration file is located at `/etc/flowgate/flowgate.yaml`.

**Example `flowgate.yaml`:**

```yaml
settings:
  proxy_ip: "0.0.0.0" # Public IP of your proxy server

domains:
  # Passthrough Proxies (SNI Proxy)
  openai.com: {type: proxy}
  anthropic.com: {type: proxy}

  # Local Services (Reverse Proxy)
  my-app.local:
    type: service
    ip: 127.0.0.1
    port: 8080
```

## Docker

Flowgate is available on GitHub Container Registry. It supports multiple combinations of Proxy and DNS servers.

**Available Tags:**
*   `angie-blocky`: **Angie + Blocky** (Default). Best for performance. Angie handles SSL automatically via ACME. Blocky is lightweight and configured via files.
*   `angie-adguardhome`: **Angie + AdGuardHome**. Adds a Web UI for DNS management (AdGuardHome).
*   `nginx-blocky`: **Nginx + Blocky**. Uses standard Nginx. SSL management is handled via Certbot.
*   `nginx-adguardhome`: **Nginx + AdGuardHome**. Standard Nginx with AdGuardHome Web UI.

**Run (Default - Angie + Blocky):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 853:853 \
  -p 5000:5000 \
  -v flowgate_config:/etc/flowgate \
  -v angie_state:/var/lib/angie \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  ghcr.io/crim50n/flowgate:angie-blocky
```

**Run (Angie + AdGuardHome):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 853:853 \
  -p 5000:5000 -p 3000:3000 \
  -v flowgate_config:/etc/flowgate \
  -v angie_state:/var/lib/angie \
  -v adguard_work:/opt/AdGuardHome \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  ghcr.io/crim50n/flowgate:angie-adguardhome
```

**Run (Nginx + Blocky):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 853:853 \
  -p 5000:5000 \
  -v flowgate_config:/etc/flowgate \
  -v letsencrypt_certs:/etc/letsencrypt \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  ghcr.io/crim50n/flowgate:nginx-blocky
```

**Run (Nginx + AdGuardHome):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 853:853 \
  -p 5000:5000 -p 3000:3000 \
  -v flowgate_config:/etc/flowgate \
  -v letsencrypt_certs:/etc/letsencrypt \
  -v adguard_work:/opt/AdGuardHome \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  ghcr.io/crim50n/flowgate:nginx-adguardhome
```

> **Note:** If you need external access to DNS, add `-p 53:53/udp` to the run command.

**Configuration Details:**

*   **Ports:**
    *   `53/udp`: DNS Service (Optional, for external DNS access).
    *   `80/tcp`: HTTP (Required for ACME challenges & Redirects).
    *   `443/tcp`: HTTPS (Required for SNI Proxy & Reverse Proxy).
    *   `853/tcp`: DNS over TLS (Optional, for DoT).
    *   `5000/tcp`: Flowgate Web Dashboard.
    *   `3000/tcp`: AdGuardHome Web Dashboard (only for AGH variants).

*   **Volumes:**
    *   `/etc/flowgate`: Stores main configuration (`flowgate.yaml`) and generated proxy configs.
    *   `/var/lib/angie`: Stores Angie state, including **ACME SSL certificates** (only for Angie variants).
    *   `/etc/letsencrypt`: Stores Certbot SSL certificates (only for Nginx variants).
    *   `/opt/AdGuardHome`: Stores AdGuardHome configuration and data (only for AGH variants).

*   **Environment Variables:**
    *   `ENABLE_WEB_UI`: Set to `true` to enable the Flowgate Web UI.
    *   `PROXY_IP`: Public IP address of the server. Set to `auto` to auto-detect (default), or specify manually.
    *   `DNS_DOMAIN`: (Optional) Domain name for DoH/DoT (e.g., `dns.example.com`).

**Build from Source:**
```bash
# Default (Angie + Blocky)
docker build -t flowgate -f Dockerfile.angie-blocky .

# Other variants
docker build -t flowgate:agh -f Dockerfile.angie-adguardhome .
```

## Architecture

Flowgate manages configuration for:

**Proxy Layer (Angie/Nginx):**
- **Stream Module:** SNI passthrough for HTTPS traffic (AI services)
- **HTTP Module:** Reverse proxy with SSL termination (local services)

**DNS Layer (Blocky/AdGuardHome):**
- Resolves DNS queries for managed domains
- Points domains to your proxy IP for traffic interception

## License

GPL-3.0 - see [LICENSE](LICENSE) file for details
