#! /bin/bash


NAMESPACE=$USER
DOMAIN_ID=0

helm install ros-slam-unity . \
--namespace $NAMESPACE --create-namespace \
--set pod.name="ros2-slam-unity" \
--set labels.user=$USER \
--set role=slam-unity \
--set domain.id=$DOMAIN_ID

helm install ros-bridges-service . \
--namespace $NAMESPACE --create-namespace \
--set pod.name="ros-bridges-service" \
--set labels.user=$USER \
--set role=service

echo "Waiting for all pods in namespace $NAMESPACE to be ready..."

while true; do
  pending=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | \
    awk '{if ($3 != "Running" && $3 != "Completed") print}' | wc -l)

  if [ "$pending" -eq 0 ]; then
    echo "All pods in namespace $NAMESPACE are running or completed."
    break
  else
    echo "$pending pods are still not ready... waiting."
    sleep 10
  fi
done

EXTERNAL_IP=$(kubectl get svc ros-bridges-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Your Pros_app's External IP: $EXTERNAL_IP"