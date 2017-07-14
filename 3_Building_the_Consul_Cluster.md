# Chapter 2 - Building the Consul Cluster

### Prerequisites

* A XenServer 7.2 Environment
* XenCenter 7.2
* the `centos-7-micro` template as built in [Chapter 1](2_The_Base_Box.md).
* a workstation with the following
	* [Terraform](https://www.terraform.io/downloads.html)
	* terraform-xenserver-provider (as built in [Appendix B](B_Building_terraform-xenserver-provider.md))

### Goal

By the time we have completed this section, you will have a functional three node Consul cluster and be able to inspect its status via the web UI.

## Terraform Consul nodes

Create a project directory that will hold your terraform files and states.  Since I would like to be able to provision and destroy each infrastructure component individually, I will make a subfolder in my project directory for Consul, Vault, Nomad servers, and Nomad clients.

```
└── play_cluster
    ├── consul
    ├── nomad-server
    ├── nomad-client
    └── vault
```
   
Switch to your consul folder.

### Create the consul.tf file
Create a consul.tf file with the following information.  Replace placeholders in "«»" with appropriate values from your environment.

```
provider "xenserver" {
    url = "«XenServer URL»"
    username = "«XenServer user name»"
    password = "«XenServer password»"
}

resource "xenserver_vm" "consul-server-1" {
    name_label = "consul-server-1"
    base_template_name = "centos-7-micro"
    xenstore_data {
    }
}

resource "xenserver_vm" "consul-server-2" {
    name_label = "consul-server-2"
    base_template_name = "centos-7-micro"
    xenstore_data {
    }
}

resource "xenserver_vm" "consul-server-3" {
    name_label = "consul-server-3"
    base_template_name = "centos-7-micro"
    xenstore_data {
    }
}
```

At this point, you should be able to run `terraform plan` and see that three resources will be created.

Run `terraform apply` to build your three nodes.

## Install Consul

You can perform these steps on one node at a time or on multiples at once using a tool like cssh (csshX on macOS)

### Create the `consul` user

```
useradd consul
usermod -aG wheel consul
mkdir /home/consul/.ssh
chown consul /home/consul/.ssh
chmod 700 /home/consul/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDBsCHv5Pyco+HkIDEy/x2WQWikvZ2QBFMUtXgsezFTAyNjsvrdEWgLfK0upQdVNC3Mo20KHtTh6sUSkddlBxdt8IezsjZgUs3DekuZXCEwCeEm8caWewmNwfu4CmnZZjPHjEWMENUmdAw00y3Hn57BuudyUmoMb5ktpwdIjkSPHZHxWACo4jIdgljuOg8Z0z+xcCDzkKtAeEcZPbCyC3i2hm2p1v4GsQ2Np8CI7luM+r+sXEMSraNq5FPJRFE6cEZuTuXpVXha646IWciT8P7bGdQkU89rScB73J9YDBzVzRbnVmTe0VLI2XJ76qgubTvEeFlaJnZsN6+gLLHotRUl cvoiselle@basho.com" > /home/consul/.ssh/authorized_keys
chown consul /home/consul/.ssh/authorized_keys
chmod 600 /home/consul/.ssh/authorized_keys
sudo chown consul /etc/consul.d
sudo mkdir /opt/consul
chown consul /opt/consul
passwd consul
```

### Write Consul Configuration
```
cat << CONSULCONFIG | sudo tee /etc/consul.d/config.json
{
  "server": true,
  "ui": true,
  "client_addr": "0.0.0.0",
  "datacenter": "dc1",
  "data_dir": "/opt/consul",
  "log_level": "INFO",
  "node_name": "consul-server-1",
  "watches": [
  ]
}
CONSULCONFIG
sudo chown consul /etc/consul.d/config.json
```

### Create the systemd service defintion

```
cat << CONSULSERVICE | sudo tee /etc/systemd/system/consul.service
[Unit]
Description=Consul Server
Requires=network-online.target
After=network-online.target

[Service]
User=consul
EnvironmentFile=-/etc/sysconfig/consul
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/bin/consul agent $OPTIONS -config-file=/etc/consul.d/config.json
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
CONSULSERVICE
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


### Enable and start the Consul service
```
sudo systemctl enable consul.service
sudo systemctl start consul.service
```

At this point, you should have an three node Consul cluster configuration.  You can verify this by going to the Consul Web UI.  It is accessible at **http://«Consul server ip»:8500/ui/**

You can now proceed to [build the Vault cluster](4_Building_the_Vault_Cluster.md).