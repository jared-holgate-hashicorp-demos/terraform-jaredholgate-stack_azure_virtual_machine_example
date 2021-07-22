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

mkdir /var/consul

chown consul:consul /var/consul

systemctl start consul

systemctl status consul

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

systemctl daemon-reload

systemctl start vault

systemctl status vault

while ! netstat -tna | grep 'LISTEN\>' | grep -q ':8200\>'; do
  sleep 10
  echo "Waiting for Vault to start..." 1>&2
done

vault status -address='http://127.0.0.1:8200' 1>&2

vault operator init -address='http://127.0.0.1:8200' -format='json' > /opt/vault/init.json

cat /opt/vault/init.json 1>&2

vault status -address='http://127.0.0.1:8200' 1>&2

RootToken=$(cat /opt/vault/init.json | jq -r '.root_token')

if [ -z $RootToken ]
then
    echo $RootToken > /opt/vault/root_token.txt
    #TODO: Send the root token to the Key Vault and remove it from the logs
    echo $RootToken 1>&2
    vault login $RootToken 1>&2
    vault secrets enable azure 1>&2
    vault write azure/config subscription_id="${subscription_id}" tenant_id="${tenant_id}" 1>&2
fi