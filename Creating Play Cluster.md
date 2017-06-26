# Creating Play Cluster

## On all nodes...

```
mkdir -p /var/log/journal/
sudo systemctl restart systemd-journald
```

## Install Consul

### Create Consul User

```
useradd consul
usermod -aG wheel consul
passwd consul
```

### Configure SSH Keys
```
mkdir /home/consul/.ssh
chown consul /home/consul/.ssh
chmod 700 /home/consul/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBsCHv5Pyco+HkIDEy/x2WQWikvZ2QBFMUtXgsezFTAyNjsvrdEWgLfK0upQdVNC3Mo20KHtTh6sUSkddlBxdt8IezsjZgUs3DekuZXCEwCeEm8caWewmNwfu4CmnZZjPHjEWMENUmdAw00y3Hn57BuudyUmoMb5ktpwdIjkSPHZHxWACo4jIdgljuOg8Z0z+xcCDzkKtAeEcZPbCyC3i2hm2p1v4GsQ2Np8CI7luM+r+sXEMSraNq5FPJRFE6cEZuTuXpVXha646IWciT8P7bGdQkU89rScB73J9YDBzVzRbnVmTe0VLI2XJ76qgubTvEeFlaJnZsN6+gLLHotRUl cvoiselle@basho.com" > /home/consul/.ssh/authorized_keys
chown consul /home/consul/.ssh/authorized_keys
chmod 600 /home/consul/.ssh/authorized_keys
```

### Grant ownership of Consul configuration directory
```
sudo mkdir /etc/consul.d
sudo chown consul /etc/consul.d
```

### Create Consul run directory

```
sudo mkdir -p /opt/consul/server
chown consul /opt/consul/server
```

### Make firewalld rules for consul

```
sudo firewall-cmd --zone=public --permanent --add-port=8300/tcp
sudo firewall-cmd --zone=public --permanent --add-port=8301/tcp
sudo firewall-cmd --zone=public --permanent --add-port=8302/tcp
sudo firewall-cmd --zone=public --permanent --add-port=8400/tcp
sudo firewall-cmd --zone=public --permanent --add-port=8500/tcp
sudo firewall-cmd --zone=public --permanent --add-port=8600/tcp
sudo firewall-cmd --zone=public --permanent --add-port=8600/udp
sudo firewall-cmd --reload
```

### Log out of Root and into the Consul User

### Write Consul Configuration
```
cat << CONSULCONFIG | sudo tee /etc/consul.d/config.json
{
  "client_addr": "0.0.0.0",
  "ui": true,
  "datacenter": "dc1",
  "data_dir": "/opt/consul",
  "log_level": "INFO",
  "node_name": "consul1",
  "server": true,
  "watches": [
  ]
}
CONSULCONFIG
sudo chown consul /etc/consul.d/config.json
```
### Bootstrap Consul cluster
```
/usr/local/bin/consul agent -config-dir=/etc/consul.d -bootstrap-expect=2
```
Once consul comes up, you can exit with Ctrl-C.

### Create Service Wrapper

```
cat << CONSULSERVICE | sudo tee /etc/systemd/system/consul-server.service
[Unit]
Description=Consul Server
Requires=network-online.target
After=network-online.target

[Service]
User=consul
EnvironmentFile=-/etc/sysconfig/consul
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/bin/consul agent -server $OPTIONS -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
CONSULSERVICE
```
### Enable and start the consul-server service
```
sudo systemctl enable consul-server.service
sudo systemctl start consul-server.service
```


## Install Vault

### Create Vault User

```
useradd vault
usermod -aG wheel vault
passwd vault
```

### Configure SSH Keys
```
mkdir /home/vault/.ssh
chown vault /home/vault/.ssh
chmod 700 /home/vault/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBsCHv5Pyco+HkIDEy/x2WQWikvZ2QBFMUtXgsezFTAyNjsvrdEWgLfK0upQdVNC3Mo20KHtTh6sUSkddlBxdt8IezsjZgUs3DekuZXCEwCeEm8caWewmNwfu4CmnZZjPHjEWMENUmdAw00y3Hn57BuudyUmoMb5ktpwdIjkSPHZHxWACo4jIdgljuOg8Z0z+xcCDzkKtAeEcZPbCyC3i2hm2p1v4GsQ2Np8CI7luM+r+sXEMSraNq5FPJRFE6cEZuTuXpVXha646IWciT8P7bGdQkU89rScB73J9YDBzVzRbnVmTe0VLI2XJ76qgubTvEeFlaJnZsN6+gLLHotRUl cvoiselle@basho.com" > /home/vault/.ssh/authorized_keys
chown vault /home/vault/.ssh/authorized_keys
chmod 600 /home/vault/.ssh/authorized_keys
```

### Grant ownership of vault configuration directory
```
sudo chown vault /etc/vault.d
```

### Create Vault run directory

```
sudo mkdir /opt/vault
sudo chown vault /opt/vault
```

### Allow vault user to use mlock

```
sudo setcap cap_ipc_lock=+ep $(readlink -f $(which vault))
```


### Write Vault Configuration
```
cat << VAULTCONFIG | sudo tee /etc/vault.d/config.hcl
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

ui=true
cluster_name="vault_dc1"
VAULTCONFIG
sudo chown vault /etc/vault.d/config.hcl
```

### Create Service Wrapper

```
cat << SERVICECONFIG | sudo tee /etc/systemd/system/vault-server.service
[Unit]
Description=Vault Server
Requires=network-online.target
After=network-online.target

[Service]
User=vault
EnvironmentFile=-/etc/sysconfig/vault
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/bin/vault server $OPTIONS -config=/etc/vault.d/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
SERVICECONFIG
```

### Enable and start the vault-server service
```
sudo firewall-cmd --zone=public --permanent --add-port=8200/tcp
sudo firewall-cmd --reload
sudo systemctl enable vault-server.service
sudo systemctl start vault-server.service
```

### Testing
```
export VAULT_ADDR='http://127.0.0.1:8200'
vault status
```
You will get an error similar to the following.  This is expected since we have not yet initialized the vault.

```
Error checking seal status: Error making API request.

URL: GET http://127.0.0.1:8200/v1/sys/seal-status
Code: 400. Errors:

* server is not yet initialized
```

### Initialize and unseal the vault
```
vault init
```
This will initialize the vault and generate the unseal keys and the initial root token.  You will use these in the next step to unseal the vault.

```
Unseal Key 1: 7dUdeeHk7eVRzjQ9lcr1iHDsz0zsJ4x8fC8b7XuCVKTY
Unseal Key 2: waKaXl+9SGAIfgqcZIND73j17lSaV8elVydL2CoMZBup
Unseal Key 3: +UO4UYX5zfko+53F1eIE77eiST74kXM64s8jykRvBD49
Unseal Key 4: iY7JN8xoUzpyMvhfBEx2S+YVLbPfb5+7B9mLsnWn7vvQ
Unseal Key 5: 2gFgquBTLD7BMu6RLKGU6rW+jPjJtlDfdR+j4IToBju5
Initial Root Token: e1fb6594-2cf4-920e-4a1a-3911727abc06


```
Use any three of the 5 generated keys to unseal the vault:

```
vault unseal 7dUdeeHk7eVRzjQ9lcr1iHDsz0zsJ4x8fC8b7XuCVKTY
vault unseal waKaXl+9SGAIfgqcZIND73j17lSaV8elVydL2CoMZBup
vault unseal +UO4UYX5zfko+53F1eIE77eiST74kXM64s8jykRvBD49
```

## Install Nomad


### Make firewalld rules for consul

```
sudo firewall-cmd --zone=public --permanent --add-port=4646/tcp
sudo firewall-cmd --zone=public --permanent --add-port=4647/tcp
sudo firewall-cmd --zone=public --permanent --add-port=4648/tcp
sudo firewall-cmd --zone=public --permanent --add-port=4648/udp
sudo firewall-cmd --reload
```

```
cat << NOMADSRVSERVICE | sudo tee /etc/systemd/system/nomad-server.service
[Unit]
Description=Nomad Server
Requires=network-online.target
After=network-online.target

[Service]
User=nomad
EnvironmentFile=-/etc/sysconfig/nomad-server
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/bin/nomad agent -server $OPTIONS -config=/etc/nomad.d/server.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
NOMADSRVSERVICE
```

```
cat << NOMADCLISERVICE | sudo tee /etc/systemd/system/nomad-client.service
[Unit]
Description=Nomad Client
Requires=network-online.target
After=network-online.target

[Service]
User=nomad
EnvironmentFile=-/etc/sysconfig/nomad-client
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/bin/nomad agent $OPTIONS -config=/etc/nomad.d/client.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
NOMADCLISERVICE
```

```
cat << NOMADSERVICE | sudo tee /etc/systemd/system/nomad.service
[Unit]
Description=Nomad Combined Server+Client
Requires=network-online.target
After=network-online.target

[Service]
User=nomad
EnvironmentFile=-/etc/sysconfig/nomad
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/bin/nomad agent $OPTIONS -config=/etc/nomad.d/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
NOMADSERVICE
```
```
sudo systemctl enable nomad.service
sudo systemctl start nomad.service
```
