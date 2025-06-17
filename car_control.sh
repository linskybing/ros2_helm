#! /bin/bash

kubectl exec -it $(kubectl get pods -n $USER -o name | grep ros2-) -c pros-car -n $USER -- /bin/bash
#kubectl exec -it $(kubectl get pods -n $USER -o name | grep ros2-) -n $USER -- /bin/bash
#kubectl exec -it $(kubectl get pods -n $USER -o name | grep ros2-) -c pros-cameraapi -n $USER -- /bin/bash

# r
# ros2 run pros_car_py robot_control

kubectl exec -it ros-car-control -n $USER -- /bin/bash