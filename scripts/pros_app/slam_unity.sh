#! /bin/bash

domain_id=$1
namespace=$USER
workspace=$HOME/workspace

export discovery_ip=$(kubectl get pod -l app=ros2-discovery-server -n $namespace -o jsonpath='{.items[0].status.podIP}')

helm install ros2-slam-unity . \
--namespace $namespace --create-namespace \
--set pod.name="ros2-slam-unity" \
--set labels.user=$USER \
--set role=slam-unity \
--set domain.id=$domain_id \
--set workspace.path=$workspace \
--set discover.ip=$discovery_ip

echo ""

helm install ros2-bridges-service . \
--namespace $namespace --create-namespace \
--set pod.name="ros-bridges-service" \
--set labels.user=$USER \
--set role=service

echo ""

echo "Waiting for all pods in namespace $namespace to be ready..."

last_pending=-1
while true; do
  pending=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | \
    awk '{if ($3 != "Running" && $3 != "Completed") print}' | wc -l)

  if [ "$pending" -eq 0 ]; then
    echo -e "\nAll pods in namespace $namespace are running or completed."
    break
  elif [ "$pending" -ne "$last_pending" ]; then
    echo "$pending pods are still not ready... waiting."
    last_pending=$pending
  fi
  sleep 1
done

external_ip=$(kubectl get svc ros-bridges-service -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Your Service's External IP: $external_ip"