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

show_server_status