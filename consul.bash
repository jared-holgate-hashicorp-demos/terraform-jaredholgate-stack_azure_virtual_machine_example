#!/bin/bash

echo '{' >> /opt/consul/${server_name}.json
echo '"server": true,' >> /opt/consul/${server_name}.json
echo '"node_name": "${server_name}",' >> /opt/consul/${server_name}.json
echo '"datacenter": "dc1",' >> /opt/consul/${server_name}.json
echo '"data_dir": "/var/consul/data",' >> /opt/consul/${server_name}.json
echo '"bind_addr": "0.0.0.0",' >> /opt/consul/${server_name}.json
echo '"client_addr": "0.0.0.0",' >> /opt/consul/${server_name}.json
echo '"advertise_addr": "${server_ip}",' >> /opt/consul/${server_name}.json
echo '"retry_join": ["${cluster_ips}"]' >> /opt/consul/${server_name}.json
echo '"ui": true,' >> /opt/consul/${server_name}.json
echo '"log_level": "DEBUG",' >> /opt/consul/${server_name}.json
echo '"enable_syslog": true,' >> /opt/consul/${server_name}.json
echo '"acl_enforce_version_8": false' >> /opt/consul/${server_name}.json
echo '}' >> /opt/consul/${server_name}.json
echo '' >> /opt/consul/${server_name}.json

echo '### BEGIN INIT INFO' >> /etc/systemd/system/consul.service
echo '# Provides:          consul' >> /etc/systemd/system/consul.service
echo '# Required-Start:    $local_fs $remote_fs' >> /etc/systemd/system/consul.service
echo '# Required-Stop:     $local_fs $remote_fs' >> /etc/systemd/system/consul.service
echo '# Default-Start:     2 3 4 5' >> /etc/systemd/system/consul.service
echo '# Default-Stop:      0 1 6' >> /etc/systemd/system/consul.service
echo '# Short-Description: Consul agent' >> /etc/systemd/system/consul.service
echo '# Description:       Consul service discovery framework' >> /etc/systemd/system/consul.service
echo '### END INIT INFO' >> /etc/systemd/system/consul.service
echo '' >> /etc/systemd/system/consul.service
echo '[Unit]' >> /etc/systemd/system/consul.service
echo 'Description=Consul server agent' >> /etc/systemd/system/consul.service
echo 'Requires=network-online.target' >> /etc/systemd/system/consul.service
echo 'After=network-online.target' >> /etc/systemd/system/consul.service
echo '' >> /etc/systemd/system/consul.service
echo '[Service]' >> /etc/systemd/system/consul.service
echo 'User=consul' >> /etc/systemd/system/consul.service
echo 'Group=consul' >> /etc/systemd/system/consul.service
echo 'PIDFile=/var/run/consul/consul.pid' >> /etc/systemd/system/consul.service
echo 'PermissionsStartOnly=true' >> /etc/systemd/system/consul.service
echo 'ExecStartPre=-/bin/mkdir -p /var/run/consul' >> /etc/systemd/system/consul.service
echo 'ExecStartPre=/bin/chown -R consul:consul /var/run/consul' >> /etc/systemd/system/consul.service
echo 'ExecStart=/usr/local/bin/consul agent \' >> /etc/systemd/system/consul.service
echo '    -config-file=/opt/consul/${server_name}.json \' >> /etc/systemd/system/consul.service
echo '    -pid-file=/var/run/consul/consul.pid' >> /etc/systemd/system/consul.service
echo 'ExecReload=/bin/kill -HUP $MAINPID' >> /etc/systemd/system/consul.service
echo 'KillMode=process' >> /etc/systemd/system/consul.service
echo 'KillSignal=SIGTERM' >> /etc/systemd/system/consul.service
echo 'Restart=on-failure' >> /etc/systemd/system/consul.service
echo 'RestartSec=42s' >> /etc/systemd/system/consul.service
echo '' >> /etc/systemd/system/consul.service
echo '[Install]' >> /etc/systemd/system/consul.service
echo 'WantedBy=multi-user.target' >> /etc/systemd/system/consul.service
echo '' >> /etc/systemd/system/consul.service

systemctl daemon-reload

sudo systemctl start consul

sudo systemctl status consul