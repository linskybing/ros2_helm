#! /bin/bash


NAMESPACE=$USER
DOMAIN_ID=32
ROLE=discovery

# helm install ros-discovery-server . \
# --namespace $NAMESPACE --create-namespace \
# --set pod.name="ros2-discovery-server" \
# --set role=$ROLE \
# --set domain.id=$DOMAIN_ID

# kubectl wait --for=condition=Ready pod -l app=ros2-discovery-server --timeout=60s -n $NAMESPACE

#export DISCOVERY_IP=$(kubectl get pod -l app=ros2-discovery-server -n $NAMESPACE -o jsonpath='{.items[0].status.podIP}')
export DISCOVERY_IP="10.121.124.22:11811"

envsubst < super.xml.template > super.xml

kubectl create configmap fastdds-super-config --from-file=super.xml=super.xml -n $NAMESPACE

helm install ros-slam-unity . \
--namespace $NAMESPACE --create-namespace \
--set pod.name="ros2-slam-unity" \
--set labels.user=$USER \
--set role=slam \
--set discover.ip=$DISCOVERY_IP \
--set domain.id=$DOMAIN_ID

helm install ros-car-control . \
--namespace $NAMESPACE --create-namespace \
--set pod.name="ros-car-control" \
--set labels.user=$USER \
--set role=car \
--set discover.ip=$DISCOVERY_IP \
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
    sleep 2
  fi
done

EXTERNAL_IP=$(kubectl get svc ros-bridges-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Your Pros_app's External IP: $EXTERNAL_IP"