# Flowgate

**Network Flow Controller (DNS & Proxy Manager)**

Flowgate is a modern CLI tool and Web UI designed to manage your network flow infrastructure. It unifies the configuration of Layer 4/7 proxies (Nginx or Angie) and DNS servers (Blocky or AdGuardHome), making it easy to route traffic, manage local services, and bypass regional restrictions for AI services.

## Features

*   **Unified Management:** Control both your Proxy and DNS server from a single interface.
*   **AI Service Proxying:** Pre-configured list of popular AI services (OpenAI, Google Gemini, Claude, etc.) to easily proxy and bypass restrictions.
*   **Local Service Discovery:** Easily expose local applications via reverse proxy with automatic DNS records.
*   **Web Dashboard:** A user-friendly web interface to manage domains and services.
*   **Automated SSL:** Automatic certificate management via Certbot (for Nginx) or native ACME (for Angie).
*   **Flexible Architecture:** Supports multiple backends:
    *   **Proxy:** Nginx or Angie
    *   **DNS:** Blocky or AdGuardHome

## Installation

### Prerequisites

Flowgate requires the following components:
- **DNS Server:** Blocky or AdGuardHome
- **Proxy Server:** Nginx or Angie

These can be installed via your distribution's package manager.

### Option 1: From Source

```bash
sudo make install          # CLI only
sudo make install WEB=1    # CLI + Web UI
```

### Option 2: Docker

Flowgate is available on Docker Hub as `crims0n/flowgate`. It supports multiple combinations of Proxy and DNS servers.

**Available Tags:**
*   `latest`, `angie-blocky`: **Angie + Blocky** (Default). Best for performance. Angie handles SSL automatically via ACME. Blocky is lightweight and configured via files.
*   `angie-adguardhome`: **Angie + AdGuardHome**. Adds a Web UI for DNS management (AdGuardHome).
*   `nginx-blocky`: **Nginx + Blocky**. Uses standard Nginx. SSL management is handled via Certbot.
*   `nginx-adguardhome`: **Nginx + AdGuardHome**. Standard Nginx with AdGuardHome Web UI.

**Run (Default - Angie + Blocky):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 53:53/udp \
  -p 5000:5000 \
  -v flowgate_config:/etc/flowgate \
  -v angie_state:/var/lib/angie \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  crims0n/flowgate:latest
```

**Run (AdGuardHome Variant):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 53:53/udp \
  -p 5000:5000 -p 3000:3000 \
  -v flowgate_config:/etc/flowgate \
  -v angie_state:/var/lib/angie \
  -v adguard_work:/opt/AdGuardHome \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  crims0n/flowgate:angie-adguardhome
```

**Run (Nginx + Blocky):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 53:53/udp \
  -p 5000:5000 \
  -v flowgate_config:/etc/flowgate \
  -v letsencrypt_certs:/etc/letsencrypt \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  crims0n/flowgate:nginx-blocky
```

**Run (Nginx + AdGuardHome):**
```bash
docker run -d --name flowgate \
  -p 80:80 -p 443:443 -p 53:53/udp \
  -p 5000:5000 -p 3000:3000 \
  -v flowgate_config:/etc/flowgate \
  -v letsencrypt_certs:/etc/letsencrypt \
  -v adguard_work:/opt/AdGuardHome \
  -e ENABLE_WEB_UI=true \
  -e PROXY_IP=auto \
  crims0n/flowgate:nginx-adguardhome
```

**Configuration Details:**

*   **Ports:**
    *   `53/udp`: DNS Service (Required).
    *   `80/tcp`: HTTP (Required for ACME challenges & Redirects).
    *   `443/tcp`: HTTPS (Required for SNI Proxy & Reverse Proxy).
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
If you prefer to build locally:
```bash
# Default (Angie + Blocky)
docker build -t flowgate -f Dockerfile.angie-blocky .

# Other variants
docker build -t flowgate:agh -f Dockerfile.angie-adguardhome .
```

## Usage

### CLI (`flowgate`)

The `flowgate` command is the primary way to interact with the system.

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

**Set Primary DNS Domain (DoH/DoT):**
```bash
sudo flowgate dns dns.mydomain.com
```

**Remove a Domain:**
```bash
sudo flowgate remove example.com
```

**Force Configuration Sync:**
```bash
sudo flowgate sync
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

## Architecture

Flowgate manages configuration for:

**Proxy Layer (Nginx/Angie):**
- **Stream Module:** SNI passthrough for HTTPS traffic (AI services)
- **HTTP Module:** Reverse proxy with SSL termination (local services)

**DNS Layer (Blocky/AdGuardHome):**
- Resolves DNS queries for managed domains
- Points domains to your proxy IP for traffic interception

## License

GPL-3.0 - see [LICENSE](LICENSE) file for details
