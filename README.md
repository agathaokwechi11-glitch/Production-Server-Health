# Linux Server Health Monitoring & Reporting System

A modular Bash-based server health monitoring tool designed with DevOps best practices: threshold-driven alerting, structured logging with rotation, historical reporting, automated testing, CI/CD linting, and Docker support.

## Architecture
- `config/health.conf`: Centralized warning/critical thresholds, monitored services, and retention policies.
- `scripts/health_check.sh`: Core metrics collector (CPU, Memory, Disk, Systemd services) with standard monitoring exit codes (`0` Healthy, `1` Warning, `2` Critical).
- `prod_report.sh`: Production wrapper that generates timestamped reports in `reports/` and enforces retention cleanup.
- `test/test_health.sh`: Automated test suite validating threshold logic and exit code behavior.

## Quick Start
1. Make scripts executable:
   `chmod +x scripts/health_check.sh prod_report.sh test/test_health.sh`
2. Run automated tests:
   `./test/test_health.sh`
3. Generate a production report:
   `./prod_report.sh`

## Troubleshooting
- **`ssh` service shows STOPPED on WSL:** Ensure systemd is enabled in `/etc/wsl.conf` (`systemd=true`) and run `sudo systemctl enable --now ssh`.
- **Exit Code `2` on script startup:** Verify `config/health.conf` exists, is readable, and `WARNING` values are strictly lower than `CRITICAL` values.
