#! /bin/bash 

function log {
   echo ${1}
   echo ${1} >> /provision/provision.out
}

if [[ -e /provision/provision.out ]]
then
  echo "Found lock file (/provision/provision.out)... skipping provisioning."
  exit 0
fi

# the script uses the presence of a configured hostfile
# to say if it should be run or not

if [[ ! `xenstore read vm-data/hostname` ]]
then
  echo "No hostname specified in VM data... skipping provisioning."
  exit 0
fi

DIRTY=false

if [[ $(nmcli con show eth0 | wc -l) -eq 0 ]]
then
  log "Renaming connection to \"eth0\'"
  nmcli con mod "Wired connection 1" connection.id eth0
fi
Hostname=`hostname`
IPAddress=`nmcli con show eth0 | grep ipv4.addresses: | awk '{print $2}'`
IPGateway=`nmcli con show eth0 | grep ipv4.gateway: | awk '{print $2}'`
IPDNS=`nmcli con show eth0 | grep ipv4.dns: | awk '{print $2}'`

if [[ `xenstore read vm-data/hostname` ]]
then
  XenHostname=`xenstore read vm-data/hostname`
  if [[ "${XenHostname}" != "${Hostname}" ]]
  then
    log "Updating IP Address from \"${IPAddress}\" to \"${XenAddress}\""
    hostnamectl set-hostname ${XenHostname}
    DIRTY=true
  fi
fi

if [[ `xenstore read vm-data/net/ipv4_addresses` ]]
then 
  XenAddress=`xenstore read vm-data/net/ipv4_addresses`
  if [[ "${XenAddress}" != "${IPAddress}" ]]
  then
    log "Updating IP Address from \"${IPAddress}\" to \"${XenAddress}\""
    nmcli con mod eth0 ipv4.method manual ipv4.addresses ${XenAddress} 
    DIRTY=true
  fi
fi

if [[ `xenstore read vm-data/net/gateway` ]]
then
  XenGateway=`xenstore read vm-data/net/gateway`
  if [[ ${XenGateway} != ${IPGateway} ]]
  then
    log "Updating IP Gateway from \"${IPGateway}\" to \"${XenGateway}\""
     nmcli con mod eth0 ipv4.gateway ${XenGateway} 
     DIRTY=true
  fi
fi

if [[ `xenstore read vm-data/net/dns` ]]
then
  XenDNS=`xenstore read vm-data/net/dns`
  if [[ "${XenDNS}" != "${IPDNS}" ]]
  then
    log "Updating DNS IP address from \"${IPDNS}\" to \"${XenDNS}\""
    nmcli con mod eth0 ipv4.method manual ipv4.dns ${XenDNS} 
    DIRTY=true
  fi
fi

if [[ "$DIRTY" = "true" ]]
then
   log "Restarting node because of changes."
   shutdown -r now
fi
