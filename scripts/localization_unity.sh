#! /bin/bash


NAMESPACE=$USER
DOMAIN_ID=0
WORKSPACE=$HOME/workspace

echo ""

helm install ros-localization-unity . \
--namespace $NAMESPACE --create-namespace \
--set pod.name="ros2-localization-unity" \
--set labels.user=$USER \
--set role=localization-unity \
--set domain.id=$DOMAIN_ID \
--set workspace.path=$WORKSPACE

echo ""

helm install ros-bridges-service . \
--namespace $NAMESPACE --create-namespace \
--set pod.name="ros-bridges-service" \
--set labels.user=$USER \
--set role=service \
--set workspace.path=$WORKSPACE

echo ""

echo "Waiting for all pods in namespace $NAMESPACE to be ready..."

last_pending=-1
while true; do
  pending=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | \
    awk '{if ($3 != "Running" && $3 != "Completed") print}' | wc -l)

  if [ "$pending" -eq 0 ]; then
    echo -e "\nAll pods in namespace $NAMESPACE are running or completed."
    break
  elif [ "$pending" -ne "$last_pending" ]; then
    echo "$pending pods are still not ready... waiting."
    last_pending=$pending
  fi
  sleep 1
done

EXTERNAL_IP=$(kubectl get svc ros-bridges-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Your Service's External IP: $EXTERNAL_IP"