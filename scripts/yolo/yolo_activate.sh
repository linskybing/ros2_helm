#! /bin/bash

domain_id=$1
namespace=$USER
workspace=$HOME/workspace

export discovery_ip=$(kubectl get pod -l app=ros2-discovery-server -n $namespace -o jsonpath='{.items[0].status.podIP}'):11811

helm install ros2-yolo . \
--namespace $namespace --create-namespace \
--set pod.name="ros2-yolo" \
--set labels.user=$USER \
--set role=yolo \
--set discover.ip=$discovery_ip \
--set workspace.path=$workspace \
--set domain.id=$domain_id --wait