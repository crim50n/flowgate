# v1.1.3

## Critical Fixes

### DoH/DoT Functionality
- **Fixed HTTPS proxy pass for DoH/DoT services**: Changed `proxy_pass` from `http://` to `https://` for port 8443 services (Blocky/AdGuardHome HTTPS endpoint)
- DoH (DNS-over-HTTPS) and DoT (DNS-over-TLS) now work correctly out of the box

### Auto-Configuration
- **Auto-configure Angie http block**: Flowgate now automatically adds `resolver` and `variables_hash_bucket_size` to existing Angie configurations
- No more manual configuration of `/etc/angie/angie.conf` required

### Security Improvements
- **Secure certificate access for DNS servers**: Instead of making certificates world-readable (644), Flowgate now:
  - Detects installed DNS server (`blocky` or `adguardhome` user)
  - Adds DNS server user to appropriate group (`angie` or `www-data`/`nginx`)
  - Sets group ownership on certificate directories
  - Uses secure permissions: 750 for directories, 640 for certificate files
  - Private keys no longer exposed to all system users

## Technical Details

### Changed Files
- `flowgate` script: Modified `sync_angie()` and `sync_nginx()` functions to:
  - Use HTTPS for DoH/DoT backend connections
  - Detect and configure permissions for both Blocky and AdGuardHome
  - Grant certificate access via group membership
  - Set proper group ownership and permissions on certificates
- Added `_ensure_http_block_settings()` function to auto-configure Angie http block

### Permissions Structure

**Angie (native ACME)**:
```
/var/lib/angie/acme/
├── acme_dns_example_com/          # drwxr-x--- (750) root:angie
│   ├── account.key                # -rw------- (600) root:root
│   ├── certificate.pem            # -rw-r----- (640) root:angie
│   └── private.key                # -rw-r----- (640) root:angie
```

**Nginx (certbot)**:
```
/etc/letsencrypt/
├── live/                          # drwxr-x--- (750) root:www-data
│   └── example.com/               # drwxr-x--- (750) root:www-data
│       ├── fullchain.pem          # -rw-r----- (640) root:www-data
│       └── privkey.pem            # -rw-r----- (640) root:www-data
├── archive/                       # drwxr-x--- (750) root:www-data
```
