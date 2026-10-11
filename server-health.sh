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

    if (( "$usage" < "$CPU_WARNING" )); then
        echo "OK"
    elif (( "$usage" <= "$CPU_CRITICAL" )); then
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
    local status

    while read -r filesystem usage; do
    status=$(get_disk_status "$usage")
    printf "%-20s %3s%% [%s]\n" "$filesystem" "$usage" "$status"
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
    

}

check_disk_usage



