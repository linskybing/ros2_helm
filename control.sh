#!/bin/bash

namespace=$USER
domain_id=0
registry=
external_ip=
declare -A scripts_by_dir
scripts=()
child_pids=()
silent=false

print_discovery_log=true
discovery_server_name=ros2-discovery-server

check_or_create_discovery_server() {
    echo -n "Checking for existing discovery server pod..."
    if ! kubectl get pod "$discovery_server_name" -n "$namespace" &>/dev/null; then
        echo " not found. Creating..."
        if [[ "$silent" == true ]]; then
            if [[ "$print_discovery_log" == true ]]; then
                helm install ros2-discovery-server . \
                    --namespace $namespace --create-namespace \
                    --set pod.name="ros2-discovery-server" \
                    --set role=discovery \
                    --set domain.id=$domain_id
            else
                helm install ros2-discovery-server . \
                    --namespace $namespace --create-namespace \
                    --set pod.name="ros2-discovery-server" \
                    --set role=discovery \
                    --set domain.id=$domain_id > /dev/null 2>&1
            fi
        else
            helm install ros2-discovery-server . \
                --namespace $namespace --create-namespace \
                --set pod.name="ros2-discovery-server" \
                --set role=discovery \
                --set domain.id=$domain_id
        fi
        echo -n "Waiting for discovery server to be ready..."
        kubectl wait --for=condition=Ready pod "$discovery_server_name" -n "$namespace" --timeout=30s || {
            echo " Discovery server failed to start."
        }
    else
        echo " already running."
    fi
}

show_menu() {
    clear
    echo "Choose a script to run:"
    i=1
    for dir in $(printf "%s\n" "${!scripts_by_dir[@]}" | sort); do
        echo ""
        echo "[$dir]"
        mapfile -t dir_scripts < <(printf "%b" "${scripts_by_dir[$dir]}")
        for script in "${dir_scripts[@]}"; do
            echo "$i. $script"
            scripts[$i]="$script"
            ((i++))
        done
        echo ""
    done
    echo ""
    echo "s. Show running pods"
    echo "e. Exec into pod/container"
    echo "x. Delete specific pod"
    echo "d. Shutdown all pods"
    echo "q. Quit"
}

exec_into_pod() {
    # Namespace input, default to "default"
    clear
    ns=$namespace
    echo " "
    echo "Listing Pods in namespace [$ns]:"

    # Get all pod names
    pods=($(kubectl get pods -n "$ns" -o jsonpath='{.items[*].metadata.name}'))

    if [ ${#pods[@]} -eq 0 ]; then
    echo "No Pods found in namespace [$ns]"
    exit 1
    fi

    # Show pod selection menu
    echo "Please select a Pod:"
    for i in "${!pods[@]}"; do
    echo "$((i+1)). ${pods[$i]}"
    done

    read -rp "Enter the number of the Pod: " pod_choice
    pod_index=$((pod_choice-1))

    if [[ $pod_index -lt 0 || $pod_index -ge ${#pods[@]} ]]; then
    echo "Invalid selection"
    exit 1
    fi

    selected_pod=${pods[$pod_index]}
    echo "You selected Pod: $selected_pod"

    # Get containers in the selected Pod
    containers=($(kubectl get pod "$selected_pod" -n "$ns" -o jsonpath='{.spec.containers[*].name}'))

    if [ ${#containers[@]} -eq 0 ]; then
    echo "No containers found in Pod $selected_pod"
    exit 1
    fi

    # Show container selection menu
    echo "Please select a container:"
    for i in "${!containers[@]}"; do
    echo "$((i+1)). ${containers[$i]}"
    done

    read -rp "Enter the number of the container: " container_choice
    container_index=$((container_choice-1))

    if [[ $container_index -lt 0 || $container_index -ge ${#containers[@]} ]]; then
    echo "Invalid selection"
    exit 1
    fi

    selected_container=${containers[$container_index]}
    echo "You selected container: $selected_container"

    echo "Starting shell session in Pod '$selected_pod', container '$selected_container'..."
    kubectl exec -it "$selected_pod" -n "$ns" -c "$selected_container" -- /bin/bash

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
}

show_all_service() {
    kubectl get all -n $namespace
}

delete_specific_pod() {
    echo "Fetching pods in namespace: $namespace..."

    mapfile -t all_pods < <(kubectl get pods -n "$namespace" --no-headers -o custom-columns=":metadata.name")

    selectable_pods=()
    for pod in "${all_pods[@]}"; do
        if [[ "$pod" != "$discovery_server_name" ]]; then
            selectable_pods+=("$pod")
        fi
    done

    if [[ ${#selectable_pods[@]} -eq 0 ]]; then
        echo "No pods available for deletion (other than discovery server)."
        return
    fi

    echo "Available pods to delete:"
    for i in "${!selectable_pods[@]}"; do
        index=$((i+1))
        echo "$index. ${selectable_pods[$i]}"
    done

    echo -n "Enter number of pod to delete: "
    read choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#selectable_pods[@]} )); then
        echo "Invalid selection."
        return
    fi

    selected_pod="${selectable_pods[$((choice-1))]}"
    echo "Attempting to uninstall Helm release for pod: $selected_pod"
    helm uninstall "$selected_pod" -n "$namespace" --wait
}

run_script() {
    local script=$1
    local print_logs=$2

    if [[ $print_logs == true ]]; then
        echo "Running $script with logs... Press 'b' to go back to menu without terminating, or 'q' to quit and terminate the process."
        "$script" $domain_id &
    else
        echo "Running $script without logs... Press 'b' to go back to menu without terminating, or 'q' to quit and terminate the process."
        "$script" $domain_id > /dev/null 2>&1 &
    fi

    script_pid=$!
    child_pids+=("$script_pid")

    while :; do
        if ! kill -0 "$script_pid" 2>/dev/null; then
            echo -e "\nProcess $script: $script_pid has finished."
            child_pids=("${child_pids[@]/$script_pid}")
            break
        fi
        read -n 1 -s -t 0.5 input
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

print_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -s, --silent               Run in silent mode (suppress script logs)"
    echo "  --no-discovery-log         Suppress Helm discovery logs"
    echo "  -h, --help                 Show this help message and exit"
    exit 0
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--silent) silent=true ;;
        --no-discovery-log) print_discovery_log=false ;;
        -h|--help) print_help ;;
    esac
    shift
done

while IFS= read -r -d '' file; do
    dir=$(dirname "$file" | sed 's|^\./||')
    relpath="./$dir/$(basename "$file")"
    scripts_by_dir[$dir]+="$relpath\n"
done < <(find ./scripts -type f -name "*.sh" -print0 | sort -z)

while true; do
    show_menu

    if [[ "$silent" == true ]]; then
        echo "\n===== Running in silent mode ====="
    fi

    echo -n "Enter your choice: "
    read choice

    if [[ $choice == "q" ]]; then
        break
    elif [[ $choice == "d" ]]; then
        shutdown_all_service
    elif [[ $choice == "s" ]]; then
        show_all_service
    elif [[ $choice == "e" ]]; then
        exec_into_pod
    elif [[ $choice == "x" ]]; then
        delete_specific_pod
    elif [[ $choice =~ ^[0-9]+$ ]] && [[ -n "${scripts[$choice]}" ]]; then
        check_or_create_discovery_server
        selected_script="${scripts[$choice]}"
        if [[ "$silent" == false || $selected_script == *"store_map.sh" ]]; then
            run_script "$selected_script" true
        else
            run_script "$selected_script" false
        fi
    else
        echo "Invalid choice. Please try again."
    fi
    echo -n "Press any key to continue..."
    read -n 1 -s
done
