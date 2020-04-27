#!/bin/bash

export CLUSTER_NAME="pikube"
export CLUSTER_TIMEZONE="Europe/Berlin"
export DEPLOYER="pikube-deployer"
export AUTHORIZED_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoD6Z60/Ceuc6X4Tex3I09na/B0TnUFCsth4V2uZjg/ matthias.lein@gmail.com"

while read -r HOST
do
  echo "Generating ssh keys for ${HOST}"

  if [ -a "certificates/id_dsa-${HOST}" ]
  then
    rm -rf certificates/id_dsa-${HOST} && echo " Deleting old DSA key"
  fi
  if [ -a "certificates/id_dsa-${HOST}.pub" ]
  then
    rm -rf certificates/id_dsa-${HOST}.pub && echo " Deleting old DSA public key"
  fi
  ssh-keygen -q -t dsa -b 1024 -o -a 100 -C "${DEPLOYER}@localhost" -N '' -f certificates/id_dsa-${HOST} || exit -1

  if [ -a "certificates/id_ecdsa-${HOST}" ]
  then
    rm -rf certificates/id_ecdsa-${HOST} && echo " Deleting old ECDSA key"
  fi
  if [ -a "certificates/id_ecdsa-${HOST}.pub" ]
  then
    rm -rf certificates/id_ecdsa-${HOST}.pub && echo " Deleting old ECDSA public key"
  fi
  ssh-keygen -q -t ecdsa -b 521 -o -a 100 -C "${DEPLOYER}@localhost" -N '' -f certificates/id_ecdsa-${HOST} || exit -1

  if [ -a "certificates/id_rsa-${HOST}" ]
  then
    rm -rf certificates/id_rsa-${HOST} && echo " Deleting old RSA key"
  fi
  if [ -a "certificates/id_rsa-${HOST}.pub" ]
  then
    rm -rf certificates/id_rsa-${HOST}.pub && echo " Deleting old RSA public key"
  fi
  ssh-keygen -q -t rsa -b 4096 -o -a 100 -C "${DEPLOYER}@localhost" -N '' -f certificates/id_rsa-${HOST} || exit -1

  if [ -a "certificates/id_ed25519-${HOST}" ]
  then
    rm -rf certificates/id_ed25519-${HOST} && echo " Deleting old ED25519 key"
  fi
  if [ -a "certificates/id_ed25519-${HOST}.pub" ]
  then
    rm -rf certificates/id_ed25519-${HOST}.pub && echo " Deleting old ED25519 public key"
  fi
  ssh-keygen -q -t ed25519 -a 100 -C "${DEPLOYER}@localhost" -N '' -f certificates/id_ed25519-${HOST} || exit -1

  echo "Generating cloudconfig user.data file for ${HOST}"

  if [ -a "configuration/user-data-${HOST}" ]
  then
    rm -rf configuration/user-data-${HOST} && echo " Deleting old user-data"
  fi

  # Fill ssh key variables
  ECDSA_PRIVATE_KEY=`while read -r LINE; do echo "    ${LINE}"; done < certificates/id_ecdsa-${HOST}`
  ECDSA_PUBLIC_KEY=`cat certificates/id_ecdsa-${HOST}.pub`
  DSA_PRIVATE_KEY=`while read -r LINE; do echo "    ${LINE}"; done < certificates/id_dsa-${HOST}`
  DSA_PUBLIC_KEY=`cat certificates/id_dsa-${HOST}.pub`
  RSA_PRIVATE_KEY=`while read -r LINE; do echo "    ${LINE}"; done < certificates/id_rsa-${HOST}`
  RSA_PUBLIC_KEY=`cat certificates/id_rsa-${HOST}.pub`
  ED25519_PRIVATE_KEY=`while read -r LINE; do echo "    ${LINE}"; done < certificates/id_ed25519-${HOST}`
  ED25519_PUBLIC_KEY=`cat certificates/id_ed25519-${HOST}.pub`

  cat > configuration/user-data-${HOST} << EOF
#cloud-config

# Configure sudo user for deployment
users:
  - default
  - name: ${DEPLOYER}
    gecos: "${CLUSTER_NAME} deployer account"
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: users,adm,dialout,audio,plugdev,netdev,video
    lock_passwd: true
    ssh-authorized-keys:
      - {AUTHORIZED_KEY}

# Set hostname
hostname: ${HOST}

# Set timezone
timezone: "${CLUSTER_TIMEZONE}"

# Configure ssh server keys
ssh_deletekeys: true
disable_root: true
ssh_keys:
  ecdsa_private: |
${ECDSA_PRIVATE_KEY}
  ecdsa_public: ${ECDSA_PUBLIC_KEY}
  dsa_private: |
${DSA_PRIVATE_KEY}
  dsa_public: ${DSA_PUBLIC_KEY}
  rsa_private: |
${RSA_PRIVATE_KEY}
  rsa_public: ${RSA_PUBLIC_KEY}
  ed25519_private: |
${ED25519_PRIVATE_KEY}
  ed25519_public: ${ED25519_PUBLIC_KEY}

# Configure sudo user for deployment
users:
  - name: ${DEPLOYER}
    gecos: "${CLUSTER_NAME} Deployer Account"
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    groups: users,adm,dialout,audio,plugdev,netdev,video
    ssh-import-id: None
    lock_passwd: true
    ssh-authorized-keys:
      - ${AUTHORIZED_KEY}

# Reboot when the initial setup is done
power_state:
 delay: "+1"
 mode: reboot
 message: Bye Bye
 timeout: 60
 condition: True
EOF
  echo ""

done < nodes
