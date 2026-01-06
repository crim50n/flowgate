## v1.1.0

### New Features

- **Multi-Distribution Support**: Now works on 30+ Linux distributions including Debian, Ubuntu, Fedora, CentOS, RHEL, Arch, Alpine, openSUSE, Gentoo, Void, and more
- **Universal Init System Support**: Supports systemd, OpenRC, SysVinit, runit, and s6 init systems
- **New CLI Commands**:
  - `flowgate init` - Initialize configuration
  - `flowgate doctor` - System diagnostics with installation instructions
  - `flowgate start/stop/restart` - Service management

### Improvements

- **Docker**: Upgraded base image to Alpine 3.21
- **Docker**: Added healthcheck for container monitoring
- **Docker**: Added port 853 (DoT) to default configuration
- **Nginx User Detection**: Automatically detects correct nginx user for each distribution (nginx, www-data, http, wwwrun, etc.)
- **Smart Package Detection**: `flowgate doctor` now shows installation commands only for missing packages

### Bug Fixes

- Fixed Makefile install-web target file installation
- Fixed f-string escaping in Angie configuration template

### Other Changes

- Renamed FlowWeb to Flowgate Web for consistency
- Updated documentation with new features and commands
