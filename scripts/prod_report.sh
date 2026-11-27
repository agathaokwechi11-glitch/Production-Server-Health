#!/usr/bin/env bash 
set -euo pipefail

SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd  )"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_ROOT/config/health.conf}"
HEALTH_SCRIPT="$SCRIPT_DIR/health_check.sh"


if [[ ! -x "$HEALTH_SCRIPT" ]]; then
    chmod +x "$HEALTH_SCRIPT"
fi

if ! source "$HEALTH_SCRIPT"; then
    printf "[ERROR]: Failed to load health_check script file\n" >&2
    exit 2
fi

REPORT_DIR_PATH="$PROJECT_ROOT/${REPORT_DIR:-reports}"
mkdir -p "$REPORT_DIR_PATH"

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
REPORT_FILE="$REPORT_DIR_PATH/health_report_${TIMESTAMP}.txt"

#Beacause of set -e we are capturing the exit codes of 1 and 2 and saving it to prevent the script from termination

EXIT_CODE=0
"$HEALTH_SCRIPT" > "$REPORT_FILE" || EXIT_CODE=$?

# Display report to stdout as well
cat "$REPORT_FILE"


# Clean up old reports based on retention policy
#  true is used to prevent script termination.
find "$REPORT_DIR_PATH" -type -f -name "health_report_*.txt" -mtime +"${REPORT_RETENTION_DAYS:-7}" -delete 2>/dev/null || true

exit "$EXIT_CODE"






