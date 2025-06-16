#!/bin/bash

NAMESPACE=$USER

# helm uninstall ros-discovery-server -n $NAMESPACE
helm uninstall ros-slam-unity -n $NAMESPACE
helm uninstall ros-car-control -n $NAMESPACE
helm uninstall ros-bridges-service -n $NAMESPACE
kubectl delete configmap fastdds-super-config -n $USER
echo "Waiting for all resources in namespace $NAMESPACE to be deleted..."

while true; do
  remaining=$(kubectl get all -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
  if [ "$remaining" -eq 0 ]; then
    echo "All resources in namespace $NAMESPACE have been deleted."
    break
  else
    echo "$remaining resources still exist... waiting."
    sleep 2
  fi
done
