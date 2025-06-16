#! /bin/bash

kubectl exec -it ros2-slam-unity -c slam -n "$USER" -- /bin/bash -c "source /opt/ros/humble/setup.bash && \
source /workspaces/install/setup.bash && \
ros2 run nav2_map_server map_saver_cli -f /workspace/demo/map/map01/map01"