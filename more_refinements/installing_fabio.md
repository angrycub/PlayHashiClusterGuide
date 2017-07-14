## Installing Fabio on your Cluster

From the [fabio README](https://github.com/fabiolb/fabio):

> fabio is a fast, modern, zero-conf load balancing HTTP(S) and TCP router for deploying applications managed by consul.

This provides a handy way to build a simple Nomad-aware load balancer.

Connect to your nomad-server-1 machine as the nomad user.

Create a fabio.nomad file:

```
job "fabio" {
  datacenters = ["dc1"]
  type = "system"
  update {
    stagger = "5s"
    max_parallel = 1
  }

  group "fabio" {
    task "fabio" {
      driver = "exec"
      config {
        command = "fabio-1.5.0-go1.8.3-linux_amd64"
      }

      artifact {
        source = "https://github.com/fabiolb/fabio/releases/download/v1.5.0/fabio-1.5.0-go1.8.3-linux_amd64"
        options {
          checksum = "sha256:7dc786c3dfd8c770d20e524629d0d7cd2cf8bb84a1bf98605405800b28705198"
        }
      }

      resources {
        cpu = 500
        memory = 64
        network {
          mbits = 1

          port "http" {
            static = 9999
          }
          port "ui" {
            static = 9998
          }
        }
      }
    }
  }
}

```


