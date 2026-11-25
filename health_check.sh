#!/usr/bin/env bash 
set -euo pipefail

SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")"  && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd  )"
CONFIG_FILE="${CONFIG_FILE:-$PROJECT_ROOT/Production_Server_Health/config/health.conf}"

#Configuration loading and validaition

#To check if configuration file is readable
if [[ ! -r "$CONFIG_FILE" ]];then
    printf '[ERROR] Cannot read config file: %s\n'  "$CONFIG_FILE" >&2
    exit 2
fi
#To check if configuration file can be loaded here
if ! source "$CONFIG_FILE"; then
    printf "[ERROR] Failed to load config file\n" >&2
    exit 2 
fi

validate_config() {
    local required_vars=(CPU_WARNING CPU_CRITICAL MEMORY_WARNING MEMORY_CRITICAL DISK_WARNING DISK_CRITICAL)
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]] || ! [[ "${!var}" =~ ^[0-9]+$ ]]; then
            printf "[ERROR] Invalid or missing numeric config vaiable: %s\n" "$var" >&2
            exit 2
        fi

        if (( CPU_WARNING >= CPU_CRITICAL || MEMORY_WARNING >= MEMORY_CRITICAL || DISK_WARNING >= DISK_CRITICAL  ));then
            printf "[ERROR] Warning Thresholds must be less than critical thresholds.\n" >&2
            exit 2
        fi
    done

}
    
validate_config

LOG_PATH="$PROJECT_ROOT/${LOG_DIR:-logs}"
REPORT_PATH="$PROJECT_ROOT/${REPORT_DIR:-reports}"
mkdir -p "$LOG_PATH" "$REPORT_PATH"
ACTIVE_LOG="$LOG_PATH/${LOG_FILE:-health_monitor.log}"

#LOGGING
log_msg(){
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[%s] [%s] %s\n" "$timestamp" "$level" "$message" >> "$ACTIVE_LOG"

}

rotate_logs(){
    local max_lines="${MAX_LOG_LINES:-1000}"
    if [[ -f "$ACTIVE_LOG" ]]; then
        local line_count="$(wc -l < "$ACTIVE_LOG")"
        if (( line_count > max_lines)); then
            local archive="$LOG_PATH/health_monitor_$(date '+%Y%m%d_%H%M%S').log"
            mv "$ACTIVE_LOG" "$archive"
            touch "$ACTIVE_LOG"
            log_msg "INFO" "Rotated log files to $(basename "$archive")"
        fi
    fi
}

get_system_info(){

    hostname=$(hostname)
    operating_system=$(uname)
    kernel=$(uname -r)
    current_user=$(whoami)
    uptime='Unknown'
    ip_address="Unavaliable"

    if command -v nproc >>/dev/null 2>&1; then
        cpu_count=$(nproc)
    else 
        cpu_count=1
    fi

    if [[ -r /proc/loadavg ]]; then
        load_average=$(awk '{print $1, $2, $3 }' /proc/loadavg)
    else
        load_average=$(uptime | awk -F'load averages?: ' '{print $2}' || echo "N/A")
    fi
    
    case "$operating_system" in 
        Linux) 
            uptime=$( uptime -p 2>/dev/null || uptime )
            ip_address=$(hostname -I | awk '{print $1}')
            if [[ -z "$ip_address" ]]; then
                 ip_address="127.0.0.1"
            fi
            ;;
        Darwin) 
            uptime=$(uptime)
            ;;
        *) 
            uptime="Unsuported OS"
            ;;
    esac
}

get_cpu_stats(){
    grep '^cpu ' /proc/stat | awk '{print $2,$3,$4,$5}'
}


get_cpu_usage(){
    if [[ -r /proc/stat ]]; then
        local user1 nice1 system1 idle1 user2 nice2 system2 idle2
        read -r user1 nice1 system1 idle1 <<< "$(get_cpu_stats)"
        sleep 1
        read -r user2 nice2 system2 idle2 <<< "$(get_cpu_stats)"
        awk -v u1="$user1" -v n1="$nice1" -v s1="$system1" -v i1="$idle1" \
            -v u2="$user2" -v n2="$nice2" -v s2="$system2" -v i2="$idle2" '
            BEGIN {
                t1 = u1 + n1 + s1 + i1
                t2 = u2 + n2 + s2 + i2
                tdiff = t2 - t1
                if (tdiff <= 0) { exit 2 }
                idiff = i2 - i1
                busy = tdiff - idiff
                usage = (busy * 100.0) / tdiff
                printf "%.1f\n",usage
            }
            '
    elif
         [[ "$(uname)" == "Darwin" ]]; then
        top -l 1 | awk '/CPU usage/ {gsub("%","",$3); gsub("%","",$5); printf "%.1f\n", $3 + $5}'
    else
        echo "0.0"

    fi    
}   
  


get_memory_usage(){

    if [[ -r /proc/meminfo ]]; then
        awk '/^MemTotal:/ { total = $2 }
            /^MemAvailable:/ { avail = $2 }
            END {
                if ( total <= 0 ) { exit 2}
                printf "%.1f\n", ((total - avail) * 100.0 ) / total 
            }' /proc/meminfo

   elif [[ "$(uname)" == "Darwin" ]]; then
        vm_stat | awk '
            /Pages active/ { active = $3 }
            /Pages wired/ { wired = $4 }
            /Pages free/ { free = $3 }
            END {
                gsub(/\./,"",active); gsub(/\./,"",wired); gsub(/\./,"",free)
                total = active + wired + free
                if (total <= 0) { exit 2 }
                printf "%.1f\n", ((active + wired) * 100.0) / total
            }'
    else
        echo "0.0"
    fi

}

check_threshold(){
    local value="$1"
    local warning="$2"
    local critical="$3"

    awk -v val="$value" -v war="$warning" -v cri="$critical" '
        BEGIN{
            if (val >= cri ) print "CRITICAL"
            else if ( val >= war ) print "WARNING"
            else print "OK"
        }'
}

check_disk_usage(){
    local filesystem
    local usage
    local disk_status
    local disk_exit_code=0

    while read -r filesystem usage; do
    disk_status=$( check_threshold "$usage" "$DISK_WARNING" "$DISK_CRITICAL")

    if [[ "$disk_status" == "CRITICAL" ]];then
        disk_exit_code=2
        log_msg "ERROR" "Disk critical on $filesystem (${usage}%)"
    elif [[ "$disk_status" == "WARNING" && disk_exit_code -lt 1 ]];then
        disk_exit_code=1
        log_msg "WARN" "Disk warning on $filesystem (${usage}%)"
    fi

    printf "%-20s %5s%% [%s]\n" "$filesystem" "$usage" "$disk_status"
    done  < <( 
        #To get the filesystem and its usage without the percentage
        df -P -x tmpfs -x  devtmpfs -x squashfs | 
        awk '
            NR > 1 {
                usage = $5
                    gsub("%",  "", usage)
                    
                    printf "%s %s\n" ,$6, usage
            }
        '
    )
    
    return "$disk_exit_code"
}

check_services(){
    local service
    local service_status
    local service_exit_code=0

    if ! command -v systemctl >/dev/null 2>&1; then
        printf "systemctl is not avaliable in this environment\n"
        log_msg "WARN" "systemctl command not found skipping service checks"
        return 0
    fi

    for service in "${SERVICES[@]}";do
        if  systemctl is-active --quiet "$service" ; then
            service_status='RUNNING'
            printf "%s %s [OK]\n" "$service" "$service_status"
        else
            service_status='STOPPED'
            printf "%s %s [CRITICAL]\n" "$service" "$service_status"
            service_exit_code=2
            log_msg "ERROR" "Service $service is STOPPED"
        fi
    done

    return "$service_exit_code"
}



show_health_report(){
    local cpu_usage cpu_status
    local memory_usage memory_status
    local disk_output disk_exit_code=0
    local service_output service_exit_code=0
    local overall_status="HEALTHY"
    local overall_exit_code=0

    log_msg "INFO" "Starting Health check run"

    #------------------
    # CPU
    #------------------
    
    if ! cpu_usage=$(get_cpu_usage); then
        log_msg "ERROR" "Could not get CPU usage"
        cpu_usage=N/A
        cpu_status="CRITICAL"
    else
        cpu_status=$(check_threshold "$cpu_usage" "$CPU_WARNING" "$CPU_CRITICAL")
    fi

    #------------------
    # MEMORY
    #__________________

    if ! memory_usage=$(get_memory_usage); then
        log_msg "ERROR" "Could not get MEMORY usage"
        memory_usage=N/A
        memory_status="CRITICAL"
    else
        memory_status=$(check_threshold "$memory_usage" "$MEMORY_WARNING" "$MEMORY_CRITICAL" )
    fi

    #-----------------------------
    #DETRMINE MEMORY/CPU SERVERITY
    #------------------------------
    if [[ "$cpu_status" == "CRITICAL"  || "$memory_status" == "CRITICAL" ]];then
        overall_status=CRITICAL
        overall_exit_code=2
    elif [[ "$cpu_status" == "WARNING"  || "$memory_status" == "WARNING"  ]];then
        overall_status=WARNING
        overall_exit_code=1
    fi


    #---------------------------
    # Determine Disk severity
    #--------------------------
    #handling exit code of 1 and 2, to prevent script termination because set -e
    disk_output=$(check_disk_usage) || disk_exit_code="$?"
    if [[ "$disk_exit_code" -eq 2 ]]; then
        overall_status=CRITICAL
        overall_exit_code=2
    elif [[ "$disk_exit_code" -eq 1 && "$overall_exit_code" -lt 2 ]]; then
        overall_status=WARNING
        overall_exit_code=1
    fi
    
    #---------------------------
    # Determine Service severity
    #--------------------------
    service_output=$(check_services) || service_exit_code="$?"
    if [[ "$service_exit_code" -eq 2 ]]; then
            overall_status=CRITICAL
            overall_exit_code=2
    fi

    local report_timestamp
    report_timestamp=$(date '+%Y-%m-%d %H:%M:%S')


    cat <<EOF
    ====================================================
                SERVER HEALTH REPORT
    ====================================================
    Timestamp                   : $report_timestamp
    Hostname                    : $hostname
    IP Address                  : $ip_address
    Operating System            : $operating_system
    Kernel                      : $kernel
    Current User                : $current_user
    Uptime                      : $uptime
    CPU Count                   : $cpu_count
    Load Average                : $load_average
    
    ---------RESOURCE UTILIZATION----------
    CPU Usage                   :${cpu_usage}% [${cpu_status}]
    Memory Usage                :${memory_usage}% [${memory_status}]

    ------DISK USAGE-----------
    $disk_output

    -------SERVICE STATUS--------
    $service_output

    --------------------------------------------------------------------------------
    Overall Status                :$overall_status (Exit code: $overall_exit_code)
    --------------------------------------------------------------------------------
EOF
    log_msg "INFO" "Completed health check: status=$overall_status  exit_code=$overall_exit_code"
    return  "$overall_exit_code"
   
}

# Allow sourcing this file in unit tests without auto-executing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]];then
    rotate_logs
    get_system_info
    show_health_report
    exit $?
fi




