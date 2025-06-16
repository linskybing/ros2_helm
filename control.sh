#! /bin/bash

namespace=$USER

scripts=()

child_pids=()
registry=
external_ip=

show_menu() {
    clear
    echo "Choose a script to run:"
    for i in "${!scripts[@]}"; do
        echo "$((i+1)). ${scripts[i]}"
    done
    echo "s. Show running pod"
    echo "d. Shutdown pod"
    echo "e. Show service external ip"
    echo "q. Quit"
}

shutdown_all_service() {
    if helm list -n "$namespace" -q | grep -q .; then
        echo "Uninstalling Helm releases in namespace: $namespace"
        helm list -n "$namespace" -q | xargs -n1 helm uninstall -n "$namespace"
        while true; do
            remaining=$(kubectl get all -n "$namespace" --no-headers 2>/dev/null | wc -l)
            if [ "$remaining" -eq 0 ]; then
                echo -e "\nAll resources in namespace $namespace have been deleted."
                break
            else
                echo -ne "\r$remaining resources still exist... waiting..."
                sleep 1
            fi
        done
    else
        echo "No Helm releases found in namespace: $namespace"
    fi

    echo "Waiting for all resources in namespace $namespace to be deleted..."
}


show_all_service() {
    kubectl get all -n $namespace
}

run_script() {
    local script=$1
    local print_logs=$2  # Boolean to control whether to print logs or not

    if [[ $print_logs == true ]]; then
        echo "Running $script with logs... Press 'b' to go back to menu without terminating, or 'q' to quit and terminate the process."
        "$script" &
    else
        echo "Running $script without logs... Press 'b' to go back to menu without terminating, or 'q' to quit and terminate the process."
        "$script" > /dev/null 2>&1 &
    fi

    script_pid=$!
    child_pids+=("$script_pid")

    while :; do
        read -n 1 -s input
        if [[ $input == "q" ]]; then
            echo -e "\nTerminating $script: $script_pid..."
            if kill -0 "$script_pid" 2>/dev/null; then
                kill -SIGINT "$script_pid"
                wait "$script_pid" 2>/dev/null
            fi
            child_pids=("${child_pids[@]/$script_pid}")
            break
        elif [[ $input == "b" ]]; then
            if kill -0 "$script_pid" 2>/dev/null; then
                echo -e "\nGoing back to the menu. The process $script: $script_pid will continue running."
            else
                echo -e "\nProcess $script: $script_pid has already finished."
            fi
            break
        fi
    done
}

# Function to display help message
print_help() {
    echo "Usage: $0 [options] <script>"
    echo "Options:"
    echo "  -s, --silent      Run the script in silent mode (suppress logs)"
    echo "  -h, --help        Show this help message and exit"
    echo "Script:"
    echo "  The script to execute (e.g., ./store_map.sh)."
    exit 0
}

# Default value for silent mode
silent=false

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--silent) silent=true ;;  # Set silent mode
        -h|--help) print_help ;;  # Print help and exit
    esac
    shift
done

while IFS= read -r -d '' file; do
    scripts+=("$file")
done < <(find ./scripts -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)

# Main loop
while true; do
    show_menu

    if [[ "$silent" == true ]]; then
        echo "===== Running in silent mode ====="
    fi

    read -p "Enter your choice: " choice

    if [[ $choice == "q" ]]; then
        break
    elif [[ $choice == "d" ]]; then
        echo "Shutting down pod."
        shutdown_all_service
    elif [[ $choice == "s" ]]; then
        show_all_service
    elif [[ $choice == "e" ]]; then
        external_ip=$(kubectl get svc ros-bridges-service -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        echo "Your Service's External IP: $external_ip"
    elif [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#scripts[@]} )); then
        selected_script="${scripts[$((choice-1))]}"
        
        # Determine if we want to print logs
        if [[ "$silent" == false || $selected_script == "./store_map.sh" ]]; then
            run_script "$selected_script" true  # Print logs if not in silent mode or if running store_map.sh
        else
            run_script "$selected_script" false  # Suppress logs for other scripts
        fi
    else
        echo "Invalid choice. Please try again."
    fi
    echo "Press any key to continue..."
    read -n 1 -s
done