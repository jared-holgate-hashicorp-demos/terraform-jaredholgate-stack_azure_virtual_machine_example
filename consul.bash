#!/bin/bash

cat > /opt/consul/${server_name}.json <<EOF
{
    "server": true,
    "node_name": "${server_name}",
    "datacenter": "dc1",
    "data_dir": "/var/consul/data",
    "bind_addr": "0.0.0.0",
    "client_addr": "0.0.0.0",
    "advertise_addr": "${server_ip}",
    "retry_join": ["${cluster_ips}"]
    "ui": true,
    "log_level": "DEBUG",
    "enable_syslog": true,
    "acl_enforce_version_8": false
}
EOF

cat > /etc/systemd/system/consul.service <<EOF
### BEGIN INIT INFO
# Provides:          consul
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Consul agent
# Description:       Consul service discovery framework
### END INIT INFO

[Unit]
Description=Consul server agent
Requires=network-online.target
After=network-online.target

[Service]
User=consul
Group=consul
PIDFile=/var/run/consul/consul.pid
PermissionsStartOnly=true
ExecStartPre=-/bin/mkdir -p /var/run/consul
ExecStartPre=/bin/chown -R consul:consul /var/run/consul
ExecStart=/usr/local/bin/consul agent \
    -config-file=/opt/consul/${server_name}.json \
    -pid-file=/var/run/consul/consul.pid
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

sudo systemctl start consul

sudo systemctl status consul