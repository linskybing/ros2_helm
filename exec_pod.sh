#!/bin/bash

# Namespace input, default to "default"
ns=$USER

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
