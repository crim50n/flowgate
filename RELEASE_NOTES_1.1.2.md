## v1.1.2

### Features & Improvements

- **Smart Sync Service Control**: `flowgate sync` now intelligently checks service status. If Angie or Nginx are stopped, it attempts to `start` them instead of failing on `reload`.
- **Status Verification**: Added a final health check after synchronization to warn users if services failed to start.
- **Improved Reliability**: Significantly better experience on fresh server installations where services might not be running yet.

### Technical Details

Previously, `flowgate sync` blindly issued `systemctl reload` commands. On a fresh installation where services (like Angie) were installed but not yet started, this would cause the sync to fail. The new logic checks `is_active()` status and branches between `start` and `reload` logic, ensuring a smooth setup process.
