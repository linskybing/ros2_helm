#! /bin/bash

kubectl exec -it ros2-slam-unity -c pros-car -n $USER -- /bin/bash
# kubectl exec -it ros2-discovery-server -n $USER -- /bin/bash
# kubectl exec -it ros2-slam-unity -n $USER -- /bin/bash
# fastdds discovery -i 0 -l 127.0.0.1 -p 11811