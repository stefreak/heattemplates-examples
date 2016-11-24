#!/bin/bash
# 2016 j.peschke@syseleven.de

# some generic stuff that is the same on any cluster member

# wait for a valid network configuration
until ping -c 1 syseleven.de; do sleep 5; done

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -q -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl haveged unzip wget jq git dnsmasq

wget https://releases.hashicorp.com/nomad/0.5.0/nomad_0.5.0_linux_amd64.zip
unzip nomad_0.5.0_linux_amd64.zip -d /usr/local/sbin
rm nomad_0.5.0_linux_amd64.zip
nomad version # 0.5.0

wget https://releases.hashicorp.com/consul/0.7.0/consul_0.7.0_linux_amd64.zip 
wget https://releases.hashicorp.com/consul-template/0.16.0/consul-template_0.16.0_linux_amd64.zip 
unzip consul_0.7.0_linux_amd64.zip
mv consul /usr/local/sbin/
rm consul_0.7.0_linux_amd64.zip
mkdir -p /etc/consul.d

cat <<EOF> /etc/systemd/system/nomad.service
[Unit]
Description=nomad agent
Requires=network-online.target
After=network-online.target

[Service]
User=root
EnvironmentFile=-/etc/default/nomad
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/sbin/nomad agent -config=/etc/nomad/config.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

mkdir -p /etc/nomad
cat <<EOF> /etc/nomad/config.hcl
log_level = "DEBUG"
data_dir = "/tmp/nomad"
bind_addr = "0.0.0.0"

region = "eu"

# be sure to change the datacenter for your different nodes
datacenter = "cbk1"

# this lets the server gracefully leave after a SIGTERM
leave_on_terminate = true

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

systemctl enable nomad
systemctl restart nomad

unzip consul-template_0.16.0_linux_amd64.zip
mv consul-template /usr/local/sbin/
rm consul-template_0.16.0_linux_amd64.zip

cat <<EOF> /etc/consul.d/consul.json
{
  "datacenter": "cbk1",
  "data_dir": "/tmp/consul",
  "bootstrap_expect": 3,
  "server": true
}
EOF


cat <<EOF> /etc/systemd/system/consul.service
[Unit]
Description=consul agent
Requires=network-online.target
After=network-online.target

[Service]
User=root
EnvironmentFile=-/etc/default/consul
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/sbin/consul agent \$OPTIONS -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consul
systemctl restart consul

until consul join 192.168.2.11 192.168.2.12 192.168.2.13; do sleep 2; done

# setup dnsmasq to communicate via consul
echo "server=/consul./127.0.0.1#8600" > /etc/dnsmasq.d/10-consul
systemctl restart dnsmasq

echo "finished generic core setup"

