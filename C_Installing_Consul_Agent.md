# Appendix C - Installing Consul Agent and Configuring DNS Integration


## Install Consul Agent

You can perform these steps on one node at a time or on multiples at once using a tool like cssh (csshX on macOS)

### Create the `consul` user

```
useradd consul
sudo mkdir -p /etc/consul.d
sudo chown consul /etc/consul.d
sudo mkdir -p /opt/consul/agent
chown -R consul /opt/consul
passwd consul
```

### Configure the node name

```
hostnamectl set-hostname $(xenstore-read vm-data/hostname)
echo "$(hostname -I) $(xenstore-read vm-data/hostname) " >> /etc/hosts
```

### Install Bind and Configure Consul DNS Integration

```
yum install -y bind bind-utils

sudo cp /etc/named.conf /etc/named.conf.orig

echo 'include "/etc/named.consul.conf";' | sudo tee -a /etc/named.conf

sudo sed -i 's/dnssec-enable yes/dnssec-enable no/g' /etc/named.conf

sudo sed -i 's/dnssec-validation yes/dnssec-validation no/g' /etc/named.conf

cat << CONSULCONF | sudo tee /etc/named.consul.conf
zone "consul" IN {
  type forward;
  forward only;
  forwarders { 127.0.0.1 port 8600; };
};
CONSULCONF

sudo systemctl start named
sudo systemctl enable named

```

Edit resolv.conf and configure name resolution to use your newly installed local DNS server.

```
cat << RESOLVCONF | sudo tee /etc/resolv.conf
search node.consul
nameserver 127.0.0.1
RESOLVCONF
```

### Write Consul Configuration
>**Note**: If performing this step on more than one node at a time, make sure that you have the node name correct in this file.

I am using jq ([https://stedolan.github.io/jq/](https://stedolan.github.io/jq/)) to query the Consul cluster for configuration information to be used in configuring the consul agent.  This could be done in a more manual fashion, but this facilitates the use of cssh or csshX to provision nodes.

```
wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
mv jq-linux64 /usr/local/bin/jq
chmod +x /usr/local/bin/jq
```

```
export CONSUL_IP=«IP address of one of your consul nodes.»

export CONSUL_IPS=$(curl -s http://$CONSUL_IP:8500/v1/catalog/service/consul | jq --compact-output '[.[] | .Address]')
export NODENAME_SHORT=$(xenstore-read vm-data/hostname | cut -f1 -d.)
export HOST_IP=$(hostname -I| tr -d " ")
```

```
cat << CONSULCONFIG | sudo tee /etc/consul.d/config-agent.json
{
  "retry_join": $CONSUL_IPS,
  "bind_addr": "$HOST_IP",
  "client_addr": "0.0.0.0",
  "datacenter": "dc1",
  "data_dir": "/opt/consul/agent",
  "log_level": "INFO",
  "node_name": "$NODENAME_SHORT",
  "watches": [
  ]
}
CONSULCONFIG
sudo chown consul /etc/consul.d/config-agent.json
```

>**Note**: We have to configure bind_addr in the configuration or Consul will fail to start after docker is installed because it will no longer be able to determine what address to advertise.


### Create the systemd service definition

```
cat << CONSULSERVICE | sudo tee /etc/systemd/system/consul-agent.service
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target

[Service]
User=consul
EnvironmentFile=-/etc/sysconfig/consul-agent
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/bin/consul agent \$OPTIONS -config-file=/etc/consul.d/config-agent.json
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
CONSULSERVICE
```

### Make firewalld rules for consul

```
sudo firewall-cmd --zone=public --permanent --add-port=8301/tcp
sudo firewall-cmd --reload
```


### Enable and start the consul-agent service
```
sudo systemctl enable consul-agent.service
sudo systemctl start consul-agent.service
```
