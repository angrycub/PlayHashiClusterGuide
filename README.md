# Play Hashi Cluster Guide

The goal of this guide is to walk through creating a play "Hashistack" cluster that has the feels of a production cluster, from provisioning nodes with Terraform to running a sample job on a Vault-enabled Nomad cluster.

This guide will have you building:

* 3 Consul Servers
* 2 Vault Servers
* 3 Nomad Servers
* 3 Nomad Agent machines

We also discuss how to use Terraform and the terraform-xenserver provider to provision boxes in a XenServer machine; however, these steps are relatively portable to other Terraform providers.  This would be left as an exercise for those interested in running on non XenServer-backed machines.


