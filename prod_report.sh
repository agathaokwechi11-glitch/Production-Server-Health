#!/usr/bin/env bash

show_server_status(){
    local hostname=$(hostname)
    local operating_system=$(uname)
    local kernel=$(uname -r)
    local date=$(date)
    local current_user=$(whoami)
    local uptime='Unknown'
    
    case "$operating_system" in 
        Linux) uptime=$(uptime -p 2>/dev/null);;
        Darwin) uptime=$(uptime);;
        MING*|MSYS*|CYGWIN*) uptime="Environment: Windows / Bash";;
        *) uptime="Uptime not supported";;
    esac
    echo 
    echo "==============================================="
    echo "                 SERVER STATUS                 "
    echo "Hostname: $hostname"
    echo "Operating System: $operating_system"
    echo "Kernel: $kernel"
    echo "Uptime: $uptime"
    echo "Current User: $current_user"
    echo "Date: $date"
    echo "==============================================="
    echo
}

show_disk_usage(){
    
}





usage(){
    echo "Usage: $0 <command>"
    echo "Commands includes:"
    echo "status"
    echo "disk"
    echo "memory"
    echo "cpu"
    echo "processes"
    echo "users"
    echo "logs"
    echo "all"
}

main (){
    if [[  "$#" -ne 1 ]] ; then
        usage
        return 1
    fi

    case "$1" in 
        status) show_server_status ;;
        disk) show_disk_usage ;;
        memory) show_memory_usage;;
        cpu) show_cpu_usage;;
        processes) show_processes;;
        users) show_users;;
        logs) show_logs;;
        all) all;;
        *)  echo "Error: Unknown command $1">&2
            echo " Run $0 for usage">&2
            return 1;;
    esac

}   

main "$@"