NOMAD_VERSION=0.8.4
CONSUL_VERSION=1.2.2
VAULT_VERSION=0.10.4

function installProduct() {
  # $1 - product name (consul nomad vault)
  # $2 - version (x.y.z undecorated)
  # $3 - platform (linux darwin freebsd)
  # $4 - architecture (amd64 arm64 i386)
  echo -n "Installing ${1} v${2}..."
  mkdir -p /opt/${1}/bin
  mkdir -p /opt/${1}/data
  mkdir -p /etc/${1}.d
  wget https://releases.hashicorp.com/${1}/${2}/${1}_${2}_${3}_${4}.zip
  unzip ${1}_${2}_${3}_${4}.zip
  rm ${1}_${2}_${3}_${4}.zip
  mv ${1} /opt/${1}/bin/${1}_v${2}
  ln -s /opt/${1}/bin/${1}_v${2}  /usr/local/bin/${1}
  echo " Done."
}

installProduct consul ${CONSUL_VERSION} linux amd64
installProduct nomad ${NOMAD_VERSION} linux amd64
installProduct vault ${VAULT_VERSION} linux amd64

