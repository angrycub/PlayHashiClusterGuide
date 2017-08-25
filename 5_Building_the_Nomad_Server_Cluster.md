# Chapter 4 - Building the Nomad Server Cluster

### Prerequisites

* A XenServer 7.2 Environment
* XenCenter 7.2
* the `centos-7-micro` template as built in [Chapter 1](2_The_Base_Box.md).
* a three-node Consul cluster as built in [Chapter 2](3_Building_the_Consul_Cluster.md)
* a two-node Vault cluster as built in [Chapter 3](4_Building_the_Vault_Cluster.md) **(optional)**
* a workstation with the following
	* [Terraform](https://www.terraform.io/downloads.html)
	* terraform-xenserver-provider (as built in [Appendix B](B_Building_terraform-xenserver-provider.md))

### Process

* Terraform the Nomad Server nodes.
* Install the Consul Agent on the nodes.
* Install Vault on the nodes.
* Initialize and unseal the Vault.

### Goal

By the time we have completed this section, you will have a functional three node Consul cluster and be able to inspect its status via the web UI.


## Terraform Vault nodes

Create a project directory that will hold your terraform files and states.  Since I would like to be able to provision and destroy each infrastructure component individually, I have a subfolder in my project directory for Consul, Vault, and Nomad.

```
└── play_cluster
    ├── consul
    ├── nomad-server
    ├── nomad-client
    └── vault
```
   
Switch to your nomad-server folder.

### Create the nomad-server.tf file
Create a nomad-server.tf file with the following information.  Replace placeholders in "«»" with appropriate values from your environment.

```
provider "xenserver" {
    url = "«XenServer URL»"
    username = "«XenServer user name»"
    password = "«XenServer password»"
}

resource "xenserver_vm" "nomad-server-1" {
    name_label = "nomad-server-1"
    base_template_name = "centos-7-micro"
    xenstore_data {
      hostname = "nomad-server-1.node.consul"
    }
}

resource "xenserver_vm" "nomad-server-2" {
    name_label = "nomad-server-2"
    base_template_name = "centos-7-micro"
    xenstore_data {
      hostname = "nomad-server-2.node.consul"
    }
}

resource "xenserver_vm" "nomad-server-3" {
    name_label = "nomad-server-3"
    base_template_name = "centos-7-micro"
    xenstore_data {
      hostname = "nomad-server-3.node.consul"
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
sudo mkdir -p /opt/nomad
chown -R nomad /opt/nomad
passwd nomad
```

### Write Nomad Server Configuration
```
cat << NOMADCONFIG | sudo tee /etc/nomad.d/nomad.hcl
data_dir = "/opt/nomad"
leave_on_interrupt = true
server {
  enabled          = true
  bootstrap_expect = 3
}
NOMADCONFIG
sudo chown nomad /etc/nomad.d/nomad.hcl
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
cat << NOMADSRVSERVICE | sudo tee /etc/systemd/system/nomad.service
[Unit]
Description=Nomad Server
Requires=network-online.target
After=network-online.target

[Service]
User=nomad
EnvironmentFile=-/etc/sysconfig/nomad
Environment=GOMAXPROCS=2
Restart=on-failure
ExecStart=/usr/bin/nomad agent -server \$OPTIONS -config=/etc/nomad.d/nomad.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
NOMADSRVSERVICE
```

```
sudo systemctl enable nomad.service
sudo systemctl start nomad.service
```

```
hostnamectl set-hostname $(xenstore-read vm-data/hostname)
echo "$(hostname -I) $(xenstore-read vm-data/hostname) " >> /etc/hosts
```
>**Note**: If the nomad-server service unit will not stay running and running the nomad command by hand gives you the following error:
```
==> Failed to parse HTTP advertise address: No valid advertise addresses, please set `advertise` manually
```
you need either add an advertise entry to the configuration or configure a hosts file entry that maps the nodes name to an IP address.
 
## Configure Vault for Nomad's Vault Integration

### Load the Vault Policy for Nomad

SSH to one of the Vault machines. Start by setting up the VAULT_ADDR environment variable.

```
export VAULT_ADDR="http://127.0.0.1:8200"
```

Download the policy templates from the Nomad documentation

```
curl https://nomadproject.io/data/vault/nomad-server-policy.hcl -O -s -L
curl https://nomadproject.io/data/vault/nomad-cluster-role.json -O -s -L
```

Authenticate with Vault using your root token.

```
vault auth 21c64ff1-a723-ecb7-b640-0ef4c87562e2
```

Write the Nomad policy and role to vault

```
vault policy-write nomad-server nomad-server-policy.hcl
vault write /auth/token/roles/nomad-cluster @nomad-cluster-role.json
```

Fetch a token for Nomad

```
vault token-create -policy nomad-server -period 72h
```

This will produce output similar to the following:

```
Key            	Value
---            	-----
token          	bfbcd47b-3cbe-6bab-051b-a4ba749670c6
token_accessor 	97ae2dc8-5862-61c0-0851-9c86ba05034d
token_duration 	72h0m0s
token_renewable	true
token_policies 	[default nomad-server]
```

You will use this token as on the Nomad machines to complete the vault integration.  You will use it on the servers as well as the agent machines.

### Add the token to the Nomad Servers

Add the vault token to the service unit's environment file

```
echo "VAULT_TOKEN=bfbcd47b-3cbe-6bab-051b-a4ba749670c6" | sudo tee /etc/sysconfig/nomad-server
```

Add the vault stanza to the node's nomad configuration

```
cat << VAULTSTANZA | sudo tee -a /etc/nomad.d/server.hcl
vault {
  enabled          = true
  address          = "http://vault.service.consul:8200"
  create_from_role = "nomad-cluster"
}
VAULTSTANZA
```

Restart the nomad-server service.


At this point, you should have three vault-enabled Consul Server members in your cluster.  You can verify this in your Consul Web UI.

You can now proceed to [build the Nomad Agents](6_Building_the_Nomad_Agent_Cluster.md).
