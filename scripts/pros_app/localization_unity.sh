
domain_id=$1
namespace=$USER
workspace=$HOME/workspace
release_name="ros2-bridges-service"
export discovery_ip=$(kubectl get pod -l app=ros2-discovery-server -n $namespace -o jsonpath='{.items[0].status.podIP}'):11811

if helm status "ros2-slam-unity" -n "$namespace" > /dev/null 2>&1; then
    echo "Release ros2-slam-unity exists, uninstalling..."
    helm uninstall "ros2-slam-unity" -n "$namespace" --wait
fi

helm install ros2-localization-unity . \
--namespace $namespace --create-namespace \
--set pod.name="ros2-localization-unity" \
--set labels.user=$USER \
--set role=localization-unity \
--set domain.id=$domain_id \
--set workspace.path=$workspace \
--set discover.ip=$discovery_ip

echo ""

if ! helm list -n "$namespace" | grep -q "^$release_name"; then
    helm install $release_name . \
    --namespace $namespace --create-namespace \
    --set pod.name=$release_name \
    --set labels.user=$USER \
    --set role=service \
    --set workspace.path=$workspace
    echo ""
fi

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

if ! helm list -n "$namespace" | grep -q "^$release_name"; then
    external_ip=$(kubectl get svc ros2-bridges-service -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Your Service's External IP: $external_ip"
fi