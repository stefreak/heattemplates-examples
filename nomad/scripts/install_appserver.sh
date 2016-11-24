#!/bin/bash
# 2016 j.peschke@syseleven.de

# wait for a valid network configuration
until ping -c 1 syseleven.de; do sleep 1; done

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y language-pack-en-base apt-transport-https ca-certificates
apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" | tee /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get install -y docker-engine
service docker start

cat <<EOF> /etc/nomad/config.hcl
log_level = "DEBUG"
data_dir = "/tmp/nomad"
bind_addr = "0.0.0.0"

region = "eu"

# be sure to change the datacenter for your different nodes
datacenter = "cbk1"

# this lets the server gracefully leave after a SIGTERM
leave_on_terminate = true

server {
  enabled          = true
  bootstrap_expect = 3
}

client {
  enabled	= true
}

# these settings allow Nomad to automatically find its peers through Consul
consul {
  # The address to the Consul agent.
  address = "127.0.0.1:8500"

  # The service name to register the server and client with Consul.
  server_service_name = "nomad"
  client_service_name = "nomad-client"

  # Enables automatically registering the services.
  auto_advertise = true

  # Enabling the server and client to bootstrap using Consul.
  server_auto_join = true
  client_auto_join = true
}
EOF

systemctl restart nomad

logger "finished nomad installation"
