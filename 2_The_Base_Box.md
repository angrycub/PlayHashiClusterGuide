# Chapter 1 - Building the Template

### Prerequisites

* A XenServer 7.2 Environment
* XenCenter 7.2
* CentOS 7.2 Installation Media

### Goal

Create three templates for CentOS boxes:

* centos-7-base: this machine will be used as the basis for the other instance types
* centos-7-micro: 1 vCPU, 800 MB RAM, 10 GB HDD
* centos-7-small: 2 vCPU, 1.5 GB RAM, 10 GB HDD

## Creating `centos-7-base`


### Post-installation steps

```
yum update -y
yum install -y unzip wget bind bind-utils net-tools
```

Since all of the VMs we create based on this template will be running some component of the Hashi stack, download Consul, Nomad, and Vault.  Unzip the downloads and copy the executables to `/usr/bin`

Install JQ on the box.  It can be downloaded from [https://stedolan.github.io/jq/download/](https://stedolan.github.io/jq/download/). Make the jq-linux64 executable and then copy it to /usr/local/bin/jq

```
wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
chmod +x jq-linux64
mv jq-linux64 /usr/local/bin/jq
```

Install the XenServer tools on the box; shut down the Virtual Machine.

### Convert VM to Template

In XenCenter, right click on the centos-7-base virtual machine and select **Convert to template...**.
Click the **Convert** button in the dialog box.

## Creating `centos-7-micro`

Make a copy of the centos-7-base template.  On the **Destination** page, select the **Within Pool** option and click **Next >**.

For the **Name**, replace the default value with `centos-7-micro`.  Select the **Full copy** option in the Copy Mode group.  Click **Finish** to create the copy of the template.

For the centos-7-micro template, we will need to manually lower the memory to 800 MB via the XenServer CLI because the initial CentOS 7 template enforces a  1 GB minimum at creation time.

Determine the UUID of your template by selecting clicking on **Objects** in the bottom left section of the interface.

In the **Objects by Type** tree in the upper left section, select **Custom Templates** and then select **centos-7-micro**.  In the **General** tab, the UUID will be displayed toward the bottom of the General section.  While creating my environment, my UUID was 
_0cd1c960-89ca-cc73-99bf-0e0fec7c140c_. I will use it in my sample commands, but be certain to substitute your own.

In the XenServer console I ran the following commands:

```
export $myTemp=0cd1c960-89ca-cc73-99bf-0e0fec7c140c
```
Verify that you have the correct template by listing its parameters.

```
xe template-param-list uuid=$myTemp
```

Once you are certain that you are working with the correct template, run the following commands to fix it up.

``` 
xe template-param-remove uuid=$myTemp param-name=other-config param-key=base_template_name

xe template-param-set uuid=$myTemp memory-static-min=838860800 memory-dynamic-min=838860800 memory-dynamic-max=838860800 memory-static-max=838860800

```
## Creating `centos-7-small`

Since we aren't having to work around the CentOS 7 template's recommendations, we can use the GUI for most of the work with this template.  Create a copy of the template as above in "Creating centos-7-micro".  Set the storage name to `centos-7-small`.  Once the copy is complete, go to the template and make the following changes:

* Set the memory to 1.5 GB

We will also need to make some modifications to this template to allow for it to work properly with the terraform-xenserver provider.

Get the template UUID as before.  Connect to the XenServer CLI.  Run the following command replacing the UUID with the UUID of your centos-7-small template

```
export $myTemp=38145c30-421b-da7f-fd14-91dbd5b28c90
```
then run the following commands:

```
xe template-param-remove uuid=$myTemp param-name=other-config param-key=base_template_name
```

### Complete
By this point, you will have the three templates that this guide will use for future sections.  Continue to [Chapter 2](3_Building_the_Consul_Cluster.md) to build a three-node Consul cluster.

--- 
#### Further Reading
1. How to Modify a Template's or Virtual Machine's Maximum Usable Memory [https://support.citrix.com/article/CTX126320](https://support.citrix.com/article/CTX126320)
2. [https://bugs.xenserver.org/browse/XSO-133](https://bugs.xenserver.org/browse/XSO-133)
3. [https://docs.citrix.com/content/dam/docs/en-us/xenserver/7-1/downloads/xenserver-7-1-vm-users-guide.pdf](https://docs.citrix.com/content/dam/docs/en-us/xenserver/7-1/downloads/xenserver-7-1-vm-users-guide.pdf)

