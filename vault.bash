#!/bin/bash

cat > /opt/consul/${server_name}.json <<EOF
{
    "server": false,
    "node_name": "${server_name}",
    "datacenter": "dc1",
    "data_dir": "/var/consul/data",
    "bind_addr": "${server_ip}",
    "client_addr": "127.0.0.1",
    "retry_join": ["${cluster_ips}"],
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
ExecStart=/usr/bin/consul agent \
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

sudo mkdir /var/consul

sudo chown consul:consul /var/consul

sudo systemctl start consul

sudo systemctl status consul

cat > /opt/vault/${server_name}.hcl <<EOF
listener "tcp" {
    address          = "0.0.0.0:8200"
    cluster_address  = "${server_ip}:8201"
    tls_disable      = "true"
}

storage "consul" {
    address = "127.0.0.1:8500"
    path    = "vault/"
}

seal "azurekeyvault" {
  client_id      = "${client_id}"
  client_secret  = "${client_secret}"
  tenant_id      = "${tenant_id}"
  vault_name     = "${vault_name}"
  key_name       = "${key_name}"
}

api_addr = "http://${server_ip}:8200"
cluster_addr = "https:/${server_ip}:8201"
EOF

cat > /etc/systemd/system/vault.service <<EOF
### BEGIN INIT INFO
# Provides:          vault
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Vault agent
# Description:       Vault secret management tool
### END INIT INFO

[Unit]
Description=Vault secret management tool
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
PIDFile=/var/run/vault/vault.pid
ExecStart=/usr/bin/vault server -config=/opt/vault/${server_name}.hcl -log-level=debug
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

sudo systemctl start vault

sudo systemctl status vault

sudo vault status

sudo vault operator init -address="http://127.0.0.1:8200" -format="json" > /opt/vault/init.log 2>&1
