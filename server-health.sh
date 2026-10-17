#!/usr/bin/env bash 
set -euo pipefail

SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")"  && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config/health.conf"

#To handle configuration file errors and control exit codes for script termination
if [[ ! -r "$CONFIG_FILE" ]];then
    printf 'ERROR: Cannot read config file: %s\n'  "$CONFIG_FILE" >&2
    exit 3
fi

if ! source "$CONFIG_FILE"; then
    printf "ERROR; Failed to load config file\n" >&2
    exit 3 
fi

    


get_system_info(){

    hostname=$(hostname)
    operating_system=$(uname)
    kernel=$(uname -r)
    date=$(date)
    current_user=$(whoami)
    uptime='Unknown'
    cpu_count=$(nproc)
    load_average=$(awk '{print $1, $2, $3 }' /proc/loadavg)
    ip_address="Not supported"
   
    
    case "$operating_system" in 
        Linux) 
            uptime=$(uptime -p 2>/dev/null)
            ip_address=$(hostname -I | awk '{print $1}')
            ;;
        Darwin) 
            uptime=$(uptime)
            ;;
        MING*|MSYS*|CYGWIN*) 
            uptime="Environment: Windows / Bash"
            ip_address=$(ipconfig | grep -m 1 "IPv4 Address" | awk -F: '{print $2}')
            ;;
        *) 
            uptime="Uptime not supported"
            ;;
    esac
}

get_cpu_stats(){
    local user
    local nice
    local system
    local idle
    local cpu
    local iowait
    local irq
    local softirq
    local steal
    local guest
    local guest_nice

   
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice \
    < <(grep '^cpu ' /proc/stat)
    echo "$user $nice $system $idle"
}


get_cpu_usage(){
    local user1
    local nice1
    local system1
    local idle1

    local user2
    local nice2
    local system2
    local idle2

    local total1
    local total2
    local total_difference
    local idle_difference
    local busy
    local usage

    local cpu1
    local cpu2

    cpu1=$(get_cpu_stats)

    read -r user1 nice1 system1 idle1 <<< "$cpu1"

    sleep 1

    cpu2=$(get_cpu_stats)

    read -r user2 nice2 system2 idle2 <<< "$cpu2"

    total1=$((user1 + nice1 + system1 + idle1))
    total2=$((user2 + nice2 + system2 + idle2))

    total_difference=$((total2 - total1))
    idle_difference=$((idle2 - idle1))
    busy=$((total_difference - idle_difference))
    usage=$((busy * 100 / total_difference))
    echo "$usage"
}



get_cpu_status(){
    local usage

    usage="$1"

    if (( usage < CPU_WARNING )); then
        echo "OK"
    elif (( usage < CPU_CRITICAL )); then
        echo "WARNING"
    else
        echo "CRITICAL"
    fi
}


get_memory_usage(){
    local total_memory
    local available_memory
    local used_memory
    local usage

    total_memory=$( awk '/^MemTotal:/ {print $2}' /proc/meminfo )
    available_memory=$( awk '/^MemAvailable:/ {print $2}' /proc/meminfo )
    used_memory=$(( total_memory - available_memory ))

    usage=$((used_memory * 100 / total_memory ))
    
    echo "$usage"  
}

get_memory_status(){
        local  usage="$1"

        if (( usage < MEMORY_WARNING ));then
            echo "OK"
        elif (( usage < MEMORY_CRITICAL ));then
            echo "WARNING"
        else 
            echo "CRITICAL"
        fi
}


get_disk_status (){
    local usage="$1"

    if (( usage < DISK_WARNING )); then
        echo "OK"
    elif (( usage < DISK_CRITICAL )); then
        echo "WARNING"
    else
        echo "CRITICAL"
    fi

}

check_disk_usage(){
    local filesystem
    local usage
    local disk_status
    local disk_exit_code=0

    while read -r filesystem usage; do
    disk_status=$(get_disk_status "$usage")

    if [[ "$disk_status" == "CRITICAL" ]];then
        disk_exit_code=2
    elif [[ "$disk_status" == "WARNING" && disk_exit_code -lt 1 ]];then
        disk_exit_code=1
    fi

    printf "%-40s %5s%% [%s]\n" "$filesystem" "$usage" "$disk_status"
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


show_health_report(){
    local cpu_usage
    local cpu_status

    local memory_status
    local memory_usage

    local disk_exit_code

    local overall_status=HEALTHLY
    local overall_exit_code=0

    #------------------
    # CPU
    #------------------
    cpu_usage=$( get_cpu_usage )
    cpu_status=$( get_cpu_status "$cpu_usage" ) 

    #------------------
    # MEMORY
    #__________________

    memory_usage=$( get_memory_usage )
    memory_status=$( get_memory_status "$memory_usage")

    #-----------------------------
    #DETRMINE MEMORY/CPU SERVERITY
    #------------------------------
    if [[ "$cpu_status" == "CRITICAL"  || "$memory_status" == "CRITICAL" ]];then
        overall_status=CRITICAL
        overall_exit_code=2
    elif [[ "$cpu_status" == "WARNING"  || "$memory_status" == "WARNING"  && overall_exit_code -lt 2 ]];then
        overall_status=WARNING
        overall_exit_code=1
    fi

    #-----------------------
    # Header
    #------------------------
    echo
    echo "========================================================="
    echo "                     SERVER HEALTH REPORT                "
    echo "========================================================="
    echo

    
    echo "Hostname               :            $hostname"
    echo "Ip Address             :            $ip_address"
    echo "Uptime                 :            $uptime"
    echo

    printf "Cpu usage:              %s%%          [%s]\n" "$cpu_usage" "$cpu_status"
    printf "Memory usage:           %s%%          [%s]\n" "$memory_usage" "$memory_status"
    
    
    echo

    #--------------
    # Disk report
    #--------------
    check_disk_usage
    disk_exit_code=$?

    #---------------------------
    # Determine disk severity
    #--------------------------
    if [[ "$disk_exit_code" -eq 2 ]]; then
        overall_status=CRITICAL
        overall_exit_code=2
    elif [[ "$disk_exit_code" -eq 1 && "$overall_exit_code" -lt 2 ]]; then
        overall_status=WARNING
        overall_exit_code=1
    fi

    #-------------------
    # FINAL REPORT
    #------------------

    echo
    echo "-------------------------------"
    echo "Overall status: $overall_status"
    echo "-------------------------------"

    return "$overall_exit_code"
    
}

get_system_info

show_health_report
exit $?



