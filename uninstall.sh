#!/bin/bash

NAMESPACE=$USER

helm uninstall ros-slam-unity -n $NAMESPACE
helm uninstall ros-bridges-service -n $NAMESPACE

echo "Waiting for all resources in namespace $NAMESPACE to be deleted..."

while true; do
  remaining=$(kubectl get all -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
  if [ "$remaining" -eq 0 ]; then
    echo "All resources in namespace $NAMESPACE have been deleted."
    break
  else
    echo "$remaining resources still exist... waiting."
    sleep 10
  fi
done
