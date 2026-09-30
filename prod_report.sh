#!bin/bash

show_server_status(){
    hostname=$(hostname)
    operating_system=$(uname)
    kernel=$(uname -r)
    date=$(date)
    current_user=$(whoami)
    
    case "$operating_system" in 
        Linux) uptime=$(uptime -p 2>/dev/null);;
        Darwin) uptime=$(uptime);;
        MING*|MSYS*|CYGWIN*) uptime=$(echo "Enivronment: Windows / Bash";;
        *) echo "Uptime not supported";;
    esac
    



}







usage(){
    echo "Usage: $0 <command>"
    echo "Commands:"
    echo "status"
    echo "disk"
    echo "memory"
    echo "cpu"
    echo "processes"
    echo "users"
    echo "log"
    echo "all"
}

main (){
    if [[ "$#" -eq 0 ]] || [[  "$#" -ne 1 ]] ; then
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
        log) show_log;;
        all) all;;
        *)  echo "Error: Unknown command $1">&2
            echo " Run $0 for usage">&2
            return 1;;
    esac

}   