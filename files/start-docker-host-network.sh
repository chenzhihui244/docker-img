#!/bin/bash

set -e

br_name=br0
host_interface=enahisic2i0
host_address="192.168.1.100/24"
docker_address='192.168.1.185/24'
gateway="192.168.1.2"
broadcast="192.168.1.255"
docker_image="deepin:15"
docker_name="dbd"

ip link ls $br_name > /dev/null 2>&1 || {
	brctl addbr $br_name
	ip addr add $host_address dev $br_name
	ip addr del $host_address dev $host_interface
	ip link set $br_name up
	brctl addif $br_name $host_interface
}

# start new container
cid=$(docker run -tdi --privileged --name $docker_name --hostname $docker_name --net=none $docker_image init)
pid=$(docker inspect -f '{{.State.Pid}}' $cid)

# set up netns
mkdir -p /var/run/netns
ln -s /proc/$pid/ns/net /var/run/netns/$pid

# set up bridge
ip link add l$pid type veth peer name r$pid
brctl addif $br_name l$pid
ip link set l$pid up

# set up docker interface
ip link set r$pid netns $pid
ip netns exec $pid ip link set dev r$pid name eth0
ip netns exec $pid ip link set eth0 up
ip netns exec $pid ip addr add $docker_address broadcast $broadcast dev eth0
ip netns exec $pid ip route add default via $gateway
