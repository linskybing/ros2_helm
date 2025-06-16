#! /bin/bash

kubectl exec -it $(kubectl get pods -n $USER -o name | grep ros2-) -c pros-car -n $USER -- /bin/bash

#kubectl exec -it $(kubectl get pods -n $USER -o name | grep ros2-) -c pros-cameraapi -n $USER -- /bin/bash

#kubectl create configmap gpu-sharing-config \
  --from-file=gpu.yaml \
  -n kube-system