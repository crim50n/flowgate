## v1.1.1

### Bug Fixes

- **Fixed Angie Stream Block Auto-Enablement**: `flowgate init` now automatically uncomments the `stream` block in default Angie configuration, enabling Layer 4 proxying on fresh installations
- **Auto-Cleanup**: Removes default `example.conf` from `/etc/angie/stream.d/` to prevent conflicts
- **Documentation**: Updated README to remove non-existent `angie-module-stream` package reference (stream module is built-in to Angie)

### Technical Details

Angie's default configuration ships with the `stream` block commented out. This release adds automatic detection and enablement during initialization, ensuring SNI proxy functionality works immediately after installation without manual configuration edits.
