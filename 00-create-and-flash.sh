#!/bin/bash

# Deal with command line options
unset NODES
unset KEYS
unset FLASH
unset HELP
unset VERBOSE
export ALLTASKS=YES
# Defaut names here (can be set through cli options below)
export CLUSTER_NAME="pikube"
export CLUSTER_TIMEZONE="Europe/Berlin"
export DEPLOYER="${CLUSTER_NAME}-deployer"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--nodes)
    NODE="$2"
    shift # past argument
    shift # past value
    ;;
    -k|--generate-ssh-key)
    KEYS=YES
    unset ALLTASKS
    shift # past argument
    ;;
    -f|--flash-sd-drive)
    FLASH=YES
    unset ALLTASKS
    shift # past argument
    ;;
    --cluster-name)
    CLUSTER_NAME="$2"
    shift # past argument
    shift # past value
    ;;
    --cluster-timezone)
    CLUSTER_TIMEZONE="$2"
    shift # past argument
    shift # past value
    ;;
    --deployer-username)
    DEPLOYER="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    HELP=YES
    shift # past argument
    ;;
    --verbose)
    VERBOSE=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

#
# Functions for this script are defined here
#

print_help ()
{
echo ""
echo "usage $0 [--verbose] [-h|--help]"
echo "      [-n|--nodes nodes] [-k|--generate-ssh-key] [-f|--flash-sd-drive]"
echo "      [--cluster-name name] [--cluster-timezone zone] [--deployer-username name]"
exit 0
}

#
# Start of the script itself
#

if [ "${HELP}" = "YES" ]
then
  print_help
fi


# We're going to use the first public key we find in .ssh
export AUTHORIZED_KEY=`ls ~/.ssh/*.pub | head -n 1 | xargs cat`

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
  ECDSA_PRIVATE_KEY=`while read -r LINE; do echo "    ${LINE}"; done < certificates/id_ecdsa-${HOST}` # pragma: allowlist secret
  ECDSA_PUBLIC_KEY=`cat certificates/id_ecdsa-${HOST}.pub`
  DSA_PRIVATE_KEY=`while read -r LINE; do echo "    ${LINE}"; done < certificates/id_dsa-${HOST}` # pragma: allowlist secret
  DSA_PUBLIC_KEY=`cat certificates/id_dsa-${HOST}.pub`
  RSA_PRIVATE_KEY=`while read -r LINE; do echo "    ${LINE}"; done < certificates/id_rsa-${HOST}` # pragma: allowlist secret
  RSA_PUBLIC_KEY=`cat certificates/id_rsa-${HOST}.pub`
  ED25519_PRIVATE_KEY=`while read -r LINE; do echo "    ${LINE}"; done < certificates/id_ed25519-${HOST}` # pragma: allowlist secret
  ED25519_PUBLIC_KEY=`cat certificates/id_ed25519-${HOST}.pub`

  cat > configuration/user-data-${HOST} << EOF
#cloud-config

# Configure sudo user for deployment
users:
  - default
  - name: ${DEPLOYER}
    gecos: "${CLUSTER_NAME} deployer account"
    sudo: ALL=(ALL) NOPASSWD:ALL # pragma: allowlist secret
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
    sudo: ALL=(ALL) NOPASSWD:ALL # pragma: allowlist secret
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
