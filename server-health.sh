#!/usr/bin/env bash 
set -euo pipefail

SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")"  && pwd )"
CONFIG_FILE="$SCRIPT_DIR/config/health.conf"

source "$CONFIG_FILE"

show_server_status(){
    local hostname
    local ip_address
    local operating_system
    local kernel
    local date
    local current_user
    local uptime
    local cpu_count
    local load_average

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
    echo 
    echo "==============================================="
    echo "                 SERVER STATUS                 "
    echo "Hostname:                      $hostname"
    echo "Operating System:              $operating_system"
    echo "Kernel:                        $kernel"
    echo "Uptime:                        $uptime"
    echo "Current User:                  $current_user"
    echo "Date:                          $date"
    echo "IP Address:                    $ip_address"
    echo "CPU Count:                     $cpu_count"
    echo "Load Average:                  $load_average"
    echo "==============================================="
    echo
}

get_cpu_stats(){
    local user
    local nice
    local system
    local idle
    local cpu

    read -r cpu user nice system idle < <( grep '^cpu ' /proc/stat )
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

    if (( "$usage" < "$CPU_WARNING" )); then
        echo "OK"
    elif (( "$usage" <= "$CPU_CRITICAL" )); then
        echo "WARNING"
    else
        echo "CRITICAL"
    fi
}

cpu_usage=$(get_cpu_usage)
cpu_status=$(get_cpu_status "$cpu_usage")

echo "Cpu Usage: $cpu_usage%"
echo "Cpu Status: $cpu_status"

get_memory_usage(){
    local total_memory
    local available_memory
    local used_memory
    local usage

    total_memory=$( awk '/^MemTotal:/ {print $2}' /proc/meminfo )
    available_memory=$( awk '/^MemAvailable:/ {print $2}' /proc/meminfo )
    used_memory=$(( total_memory - available_memory ))
    echo "$available_memory"

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

memory_usage=$(get_memory_usage)
memory_status=$(get_memory_status "$memory_usage")

echo "Memory Usage: $memory_usage"
echo "Memory Status: $memory_status"

