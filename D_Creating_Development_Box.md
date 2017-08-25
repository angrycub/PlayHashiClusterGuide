# Appendix D - Creating a Nomad Development Machine


## Create an instance of the Bash Box

You can use the same CentOS 7 base box that we use in the other examples.  You will need to increase the available RAM to 2 GB in order for Nomad to compile properly.

## Install OS Dependencies

```
yum groupinstall -y "Development Tools"
yum install -y unzip tree git
# to allow compiling alternate binaries, you will also need:
yum install -y glibc-devel.i686
```
## Install Golang


## Install Consul Agent
