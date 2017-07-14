# Chapter 3 - Building the Vault Cluster

### Prerequisites

* A XenServer 7.2 Environment
* XenCenter 7.2
* the `centos-7-micro` template as built in [Chapter 1](2_The_Base_Box.md).
* a three-node Consul cluster as built in [Chapter 2](3_Building_the_Consul_Cluster.md)
* a workstation with the following
	* [Terraform](https://www.terraform.io/downloads.html)
	* terraform-xenserver-provider (as built in [Appendix B](B_Building_terraform-xenserver-provider.md))

### Process

* Terraform the Vault nodes.
* Install the Consul Agent on the nodes.
* Install Vault on the nodes.
* Initialize and unseal the Vault.

### Goal

By the time we have completed this section, you will have a functional three node Consul cluster and be able to inspect its status via the web UI.


## Terraform Vault nodes

Create a project directory that will hold your terraform files and states.  Since I would like to be able to provision and destroy each infrastructure component individually, I will make a subfolder in my project directory for Consul, Vault, Nomad servers, and Nomad clients.

```
└── play_cluster
    ├── consul
    ├── nomad-server
    ├── nomad-client
    └── vault
```
   
Switch to your vault folder.

### Create the vault.tf file
Create a consul.tf file with the following information.  Replace placeholders in "«»" with appropriate values from your environment.

```
provider "xenserver" {
    url = "«XenServer URL»"
    username = "«XenServer user name»"
    password = "«XenServer password»"
}

resource "xenserver_vm" "vault-server-1" {
    name_label = "vault-server-1"
    base_template_name = "centos-7-micro"
    xenstore_data {
    }
}

resource "xenserver_vm" "vault-server-2" {
    name_label = "vault-server-2"
    base_template_name = "centos-7-micro"
    xenstore_data {
    }
}

```

At this point, you should be able to run `terraform plan` and see that three resources will be created.

Run `terraform apply` to build your three nodes.

## Install Consul Agent

See [Appendix C - Installing Consul Agent and Configuring DNS Integration](C_Installing_Consul_Agent.md)

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
sudo mkdir /etc/vault.d
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

### Add the vault firewall rules
```
sudo firewall-cmd --zone=public --permanent --add-port=8200/tcp
sudo firewall-cmd --reload
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
ExecReload=/bin/kill -HUP \$MAINPID
KillSignal=SIGINT
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
SERVICECONFIG
```

### Enable and start the vault-server service

```
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

## Initialize and unseal the vault

To initialize the Vault, run the following command:
```
vault init
```

This will initialize the vault and generate the unseal keys and the initial root token.  You will use these in the next step to unseal the vault.  Following are example values from an sample run:

```
Unseal Key 1: UjVN1EBNzqZQKrmwFxwuB3PgBiboAOS8jby35cSeBhKY
Unseal Key 2: cm0/44FnK3lJTffA0Smjy2gZiNiX8+z7IgcKv1E5WgU3
Unseal Key 3: tff7U/D/8U1vUfOTa462lMRGZCftdCwktkUJOBpOOYq0
Unseal Key 4: k6wQ41lZlc41KqAbkjbnoO6UyrneJNj/8+hhP2ZM5qq2
Unseal Key 5: z9HwWpsm5tlMwqwfw1sGrdkhgu3HaxzHp+0S03+1724N
Initial Root Token: 21c64ff1-a723-ecb7-b640-0ef4c87562e2
```
>**Note**: If you get an error that says `http: server gave HTTP response to HTTPS client`, you need to run the `export VAULT_ADDR='http://127.0.0.1:8200'` command in your session.

Use any three of the 5 generated keys to unseal the vault:

```
vault unseal UjVN1EBNzqZQKrmwFxwuB3PgBiboAOS8jby35cSeBhKY
vault unseal cm0/44FnK3lJTffA0Smjy2gZiNiX8+z7IgcKv1E5WgU3
vault unseal tff7U/D/8U1vUfOTa462lMRGZCftdCwktkUJOBpOOYq0
```
Perform the unsealing steps on the second node:

```
export VAULT_ADDR='http://127.0.0.1:8200'
vault unseal UjVN1EBNzqZQKrmwFxwuB3PgBiboAOS8jby35cSeBhKY
vault unseal cm0/44FnK3lJTffA0Smjy2gZiNiX8+z7IgcKv1E5WgU3
vault unseal tff7U/D/8U1vUfOTa462lMRGZCftdCwktkUJOBpOOYq0
```

At this point, you should have an active/standby HA vault configuration.  You can verify this in your Consul Web UI.

You can now proceed to [build the Nomad Server cluster](5_Building_the_Nomad_Server_Cluster.md).