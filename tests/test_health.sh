#!/usr/bin/env bash 
set -euo pipefail

SCRIPT_DIR=$( cd "$(dirname  "${BASH_SOURCE[0]}")" && pwd )
PROJECT_ROOT=$( cd "$SCRIPT_DIR/.." && pwd )
HEALTH_SCRIPT="$PROJECT_ROOT/scripts/health_check.sh"

if ! source "$HEALTH_SCRIPT"; then
    printf "[ERROR]: Failed to load the $HEALTH_SCRIPT file\n" >&2
    exit 2
fi

pass_count=0
fail_count=0

conduct_test(){
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [[ "$expected" == "$actual" ]];then
        printf "[PASS] %s\n" "$test_name"
        ((pass_count++)) || true
    else
        printf "[FAILED] %s (Expected: %s Actual: %s)\n" "$test_name" "$expected" "$actual"
        ((fail_count++)) || true
    fi
}

echo "Running Server Health Monitor Tests..."

# Test 1: Threshold logic (OK, WARNING, CRITICAL)
conduct_test "CPU below warning is OK" "OK" "$(check_threshold 30 70 85)"
conduct_test "CPU at warning is WARNING" "WARNING" "$(check_threshold 78 70 85)"
conduct_test "CPU above critical is CRITICAL" "CRITICAL" "$(check_threshold 90 70 85)"

# Test 2: Missing config file exits with code 2
set +e #This turns off set -e at the top of the script
CONFIG_FILE="/doesnotexist/config" bash "$HEALTH_SCRIPT" >/dev/null 2>&1
missing_config_exit="$?"
set -e #This turns it back on
conduct_test "Missing config file exits with code 2" "2" "$missing_config_exit"


# Test 3: Simulated critical threshold triggers exit code 2
TEMP_CONF="$(mktemp)"
cat <<EOF > "$TEMP_CONF"
#cpu threshold
CPU_WARNING=0
CPU_CRITICAL=1

#memory threshold
MEMORY_WARNING=0
MEMORY_CRITICAL=1

#disk threshold
DISK_WARNING=80
DISK_CRITICAL=90

#Services to monitor
SERVICES=()
EOF

set +e
CONFIG_FILE="$TEMP_CONF" bash "$HEALTH_SCRIPT" >/dev/null 2>&1
critical_exit_code="$?"
set -e

rm -f "$TEMP_CONF"
conduct_test "Critical threshold returns exit code 2" "2" "$critical_exit_code"

echo "======================================================"
printf "Tests passed %d | Tests Failed %d\n" "$pass_count" "$fail_count"

if (( fail_count > 0 ));then
    exit  1
fi




