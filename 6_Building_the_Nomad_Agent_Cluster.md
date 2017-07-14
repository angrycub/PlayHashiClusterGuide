# Chapter 5 - Building the Nomad Client Cluster

### Prerequisites

* A XenServer 7.2 Environment
* XenCenter 7.2
* the `centos-7-small` template as built in [Chapter 1](2_The_Base_Box.md).
* a three-node Consul cluster as built in [Chapter 2](3_Building_the_Consul_Cluster.md)
* a two-node Vault cluster as built in [Chapter 3](4_Building_the_Vault_Cluster.md) **(optional)**
* a three-node Nomad server cluster as built in [Chapter 4](5_Building_the_Nomad_Server_Cluster.md) 
* a workstation with the following
	* [Terraform](https://www.terraform.io/downloads.html)
	* terraform-xenserver-provider (as built in [Appendix B](B_Building_terraform-xenserver-provider.md))

### Process

* Terraform the Nomad agent nodes.
* Install the Consul agent on the nodes.
* Configure Nomad Service
* Install Docker
* Run a sample job

### Goal

By the time we have completed this section, you will have a fully functional Nomad Cluster configured to take advantage of Consul for service registration and discovery, and will have run the sample Redis job against the cluster to test Vault integration


## Terraform Nomad client nodes

Create a project directory that will hold your terraform files and states.  Since I would like to be able to provision and destroy each infrastructure component individually, I have a subfolder in my project directory for Consul, Vault, and Nomad.

```
└── play_cluster
    ├── consul
    ├── nomad-server
    ├── nomad-client
    └── vault
```
   
Switch to your nomad-client folder.

### Create the nomad-client.tf file
Create a nomad-client.tf file with the following information.  Replace placeholders in "«»" with appropriate values from your environment.

```
provider "xenserver" {
    url = "«XenServer URL»"
    username = "«XenServer user name»"
    password = "«XenServer password»"
}

resource "xenserver_vm" "nomad-client-1" {
    name_label = "nomad-client-1"
    base_template_name = "centos-7-small"
    xenstore_data {
      hostname = "nomad-client-1.node.consul"
    }
}

resource "xenserver_vm" "nomad-client-2" {
    name_label = "nomad-client-2"
    base_template_name = "centos-7-small"
    xenstore_data {
      hostname = "nomad-client-2.node.consul"
    }
}

resource "xenserver_vm" "nomad-client-3" {
    name_label = "nomad-client-3"
    base_template_name = "centos-7-small"
    xenstore_data {
      hostname = "nomad-client-3.node.consul"
    }
}

```

At this point, you should be able to run `terraform plan` and see that three resources will be created.

Run `terraform apply` to build your three nodes.

## Install Consul Agent

See [Appendix C - Installing Consul Agent and Configuring DNS Integration](C_Installing_Consul_Agent.md)

## Install Nomad 

### Create nomad user
```
useradd nomad
sudo mkdir /etc/nomad.d
sudo chown nomad /etc/nomad.d
sudo mkdir -p /opt/nomad/client
chown -R nomad /opt/nomad
passwd nomad
```

### Write Nomad Client Configuration
```
cat << NOMADCONFIG | sudo tee /etc/nomad.d/client.hcl
datacenter = "dc1"
data_dir = "/opt/nomad/client"

client {
  enabled = true
}
NOMADCONFIG
sudo chown nomad /etc/nomad.d/client.hcl
```
### Make firewalld rules for nomad

```
sudo firewall-cmd --zone=public --permanent --add-port=4646/tcp
sudo firewall-cmd --zone=public --permanent --add-port=4647/tcp
sudo firewall-cmd --zone=public --permanent --add-port=4648/tcp
sudo firewall-cmd --zone=public --permanent --add-port=4648/udp
sudo firewall-cmd --reload
```

```
cat << NOMADSRVSERVICE | sudo tee /etc/systemd/system/nomad-client.service
[Unit]
Description=Nomad Client
Requires=network-online.target
After=network-online.target

[Service]
User=nomad
EnvironmentFile=-/etc/sysconfig/nomad-client
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/local/bin/nomad agent \$OPTIONS -config=/etc/nomad.d/client.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
NOMADSRVSERVICE
```

>**Note**: If the nomad-client service unit will not stay running and running the nomad command by hand gives you the following error:
```
==> Failed to parse HTTP advertise address: No valid advertise addresses, please set `advertise` manually
```
you need either add an advertise entry to the configuration or configure a hosts file entry that maps the nodes name to an IP addres.

### Install Docker for the Sample Job

The sample job created with `nomad init` requires that Docker be installed on the Nomad client machines.  You can fetch and run the installer with this one-liner.

```
curl -fsSL https://get.docker.com/ | sh
```

Once docker is installed, you will need to add the `nomad` user to the docker group

```
sudo usermod -aG docker nomad
```

Start docker and enable it to run on boot.

```
sudo systemctl start docker
sudo systemctl enable docker
```

Verify that docker is running as expected.

```
sudo systemctl status docker
```

### Start the Nomad client service

```
sudo systemctl enable nomad-client.service
sudo systemctl start nomad-client.service
```

### Create and run a sample job

At this point, you should have three Consul client members in your cluster.  

From your workstation, connect to nomad-server-1 as the nomad user.  Run `nomad init` to generate the example job.  Run `nomad run example.nomad` to submit the job to the cluster.  Check to see if the job has started using `nomad status example`.  You can also verify this in your Consul Web UI by looking for the **global-redis-check** service to show on the services page.


