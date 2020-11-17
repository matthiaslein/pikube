#!/bin/bash

# Safety first
set -o nounset # exit if unset variable is used
set -o errexit # exit if any statement returns an error

# Deal with command line options
unset NODES
unset KEYS
unset FLASH
unset HELP
unset DEVICE
unset VERBOSE
unset OVERWRITE
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
    NODES="$2"
    shift # past argument
    shift # past value
    ;;
    -k|--generate-ssh-key)
    KEYS=YES
    unset ALLTASKS
    shift # past argument
    ;;
    -f|--flash)
    FLASH=YES
    unset ALLTASKS
    shift # past argument
    ;;
    -o|--overwrite)
    OVERWRITE=YES
    shift # past argument
    ;;
    -d|--device)
    DEVICE="$2"
    shift # past argument
    shift # past value
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
# Prints help: need to reconcile with what's defined in the cli options above
echo ""
echo "usage $0 [--verbose] [-h|--help]"
echo "      [-n|--nodes nodes] [-k|--generate-ssh-key] [-f|--flash] [-d|--device]"
echo "      [--cluster-name name] [--cluster-timezone zone] [--deployer-username name]"
echo "      [-o|--overwrite]"
exit 0
}

add_key_to_known_hosts ()
{
# Will add the public key of ${HOST} to the user's .ssh/known_hosts file
[ -n "${VERBOSE}" ] && echo " Making ${HOST}'s key known in known_hosts"
if ssh-keygen -F "${HOST}" &> /dev/null
then
  if [ -n "${VERBOSE}" ]
  then
    echo "  a key for ${HOST} is already present in the known hosts file"
  fi
else
  if [ -n "${VERBOSE}" ]
  then
    echo "  ${HOST}'s key is NOT present in the known hosts file"
    echo "  adding ${HOST},${IP_ADDRESS}"
  fi
  IP_ADDRESS=$(getent hosts "${HOST}" | awk '{ print $1 }')
  PUB_KEY=$(sed s/'== .*'/==/ certificates/id_ecdsa-"${HOST}".pub)
  echo "${HOST},${IP_ADDRESS} ${PUB_KEY}" >> ~/.ssh/known_hosts
  ssh-keygen -Hf ~/.ssh/known_hosts &> /dev/null
  rm -rf ~/.ssh/known_hosts.old
fi
}

generate_user_data_file ()
# Creates a cloud-init user_data file for ${HOST}
{
if [ -n "${VERBOSE}" ]
then
  echo " Generating cloudconfig user.data file for ${HOST}"
fi

if [ -a "configuration/user-data-${HOST}" ] && [ -n "${OVERWRITE}" ]
then
  if [ -n "${VERBOSE}" ]
  then
    echo "  Deleting old user-data"
  fi
  rm -rf configuration/user-data-"${HOST}"
fi

# Fill ssh key variables
ECDSA_PRIVATE_KEY=$(while read -r LINE; do echo "    ${LINE}"; done < certificates/id_ecdsa-"${HOST}") # pragma: allowlist secret
ECDSA_PUBLIC_KEY=$(cat certificates/id_ecdsa-"${HOST}".pub)
DSA_PRIVATE_KEY=$(while read -r LINE; do echo "    ${LINE}"; done < certificates/id_dsa-"${HOST}") # pragma: allowlist secret
DSA_PUBLIC_KEY=$(cat certificates/id_dsa-"${HOST}".pub)
RSA_PRIVATE_KEY=$(while read -r LINE; do echo "    ${LINE}"; done < certificates/id_rsa-"${HOST}") # pragma: allowlist secret
RSA_PUBLIC_KEY=$(cat certificates/id_rsa-"${HOST}".pub)
ED25519_PRIVATE_KEY=$(while read -r LINE; do echo "    ${LINE}"; done < certificates/id_ed25519-"${HOST}") # pragma: allowlist secret
ED25519_PUBLIC_KEY=$(cat certificates/id_ed25519-"${HOST}".pub)

# We're going to use the first public key we find in .ssh
AUTHORIZED_KEY=$(find ~/.ssh -iname '*.pub' | head -n 1 | xargs cat)

if [ ! -f "configuration/user-data-${HOST}" ] || [ -n "${OVERWRITE}" ]
then
cat > configuration/user-data-"${HOST}" << EOF
#cloud-config

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
fi
}

generate_ssh_server_keys ()
{
# Creates keys for ${HOST}
[ -n "${VERBOSE}" ] && echo " Generating ssh keys for ${HOST}"

if [ -a "certificates/id_dsa-${HOST}" ] && [ -n "${OVERWRITE}" ]
then
  rm -rf certificates/id_dsa-"${HOST}"
  [ -n "${VERBOSE}" ] && echo "  Deleting old DSA key"
fi
if [ -a "certificates/id_dsa-${HOST}.pub" ] && [ -n "${OVERWRITE}" ]
then
  rm -rf certificates/id_dsa-"${HOST}".pub
  [ -n "${VERBOSE}" ] && echo "  Deleting old DSA public key"
fi
if [ ! -f "certificates/id_dsa-${HOST}" ] || [ -n "${OVERWRITE}" ]
then
  [ -n "${VERBOSE}" ] && echo "  Creating new DSA key pair"
  ssh-keygen -q -t dsa -b 1024 -o -a 100 -C "${DEPLOYER}@localhost" -N '' -f certificates/id_dsa-"${HOST}" || exit 1
else
  [ -n "${VERBOSE}" ] && echo "  DSA key pair exists"
fi

if [ -a "certificates/id_ecdsa-${HOST}" ] && [ -n "${OVERWRITE}" ]
then
  rm -rf certificates/id_ecdsa-"${HOST}"
  [ -n "${VERBOSE}" ] && echo "  Deleting old ECDSA key"
fi
if [ -a "certificates/id_ecdsa-${HOST}.pub" ] && [ -n "${OVERWRITE}" ]
then
  rm -rf certificates/id_ecdsa-"${HOST}".pub
  [ -n "${VERBOSE}" ] && echo "  Deleting old ECDSA public key"
fi
if [ ! -f "certificates/id_ecdsa-${HOST}" ] || [ -n "${OVERWRITE}" ]
then
  [ -n "${VERBOSE}" ] && echo "  Creating new ECDSA key pair"
  ssh-keygen -q -t ecdsa -b 521 -o -a 100 -C "${DEPLOYER}@localhost" -N '' -f certificates/id_ecdsa-"${HOST}" || exit 1
else
  [ -n "${VERBOSE}" ] && echo "  ECDSA key pair exists"
fi

if [ -a "certificates/id_rsa-${HOST}" ] && [ -n "${OVERWRITE}" ]
then
  rm -rf certificates/id_rsa-"${HOST}"
  [ -n "${VERBOSE}" ] && echo "  Deleting old RSA key"
fi
if [ -a "certificates/id_rsa-${HOST}.pub" ] && [ -n "${OVERWRITE}" ]
then
  rm -rf certificates/id_rsa-"${HOST}".pub
  [ -n "${VERBOSE}" ] && echo "  Deleting old RSA public key"
fi
if [ ! -f "certificates/id_rsa-${HOST}" ] || [ -n "${OVERWRITE}" ]
then
  [ -n "${VERBOSE}" ] && echo "  Creating new RSA key pair"
  ssh-keygen -q -t rsa -b 4096 -o -a 100 -C "${DEPLOYER}@localhost" -N '' -f certificates/id_rsa-"${HOST}" || exit 1
else
  [ -n "${VERBOSE}" ] && echo "  RSA key pair exists"
fi

if [ -a "certificates/id_ed25519-${HOST}" ] && [ -n "${OVERWRITE}" ]
then
  rm -rf certificates/id_ed25519-"${HOST}"
  [ -n "${VERBOSE}" ] && echo "  Deleting old ED25519 key"
fi
if [ -a "certificates/id_ed25519-${HOST}.pub" ] && [ -n "${OVERWRITE}" ]
then
  rm -rf certificates/id_ed25519-"${HOST}".pub
   [ -n "${VERBOSE}" ] && echo "  Deleting old ED25519 public key"
fi
if [ ! -f "certificates/id_ed25519-${HOST}" ] || [ -n "${OVERWRITE}" ]
then
  [ -n "${VERBOSE}" ] && echo "  Creating new ED25519 key pair"
  ssh-keygen -q -t ed25519 -a 100 -C "${DEPLOYER}@localhost" -N '' -f certificates/id_ed25519-"${HOST}" || exit 1
else
  [ -n "${VERBOSE}" ] && echo "  ED25519 key pair exists"
fi
}

flash_image_to_drive ()
{

[ -n "${VERBOSE}" ] && echo " Flashing image to sd drive"

if [ -x ./packages/flash ]
then
  [ -n "${VERBOSE}" ] && echo "  flash tool found"
else
  [ -n "${VERBOSE}" ] && echo "  flash tool not found: downloading"
  mkdir -p packages
  cd packages || exit 1
  curl -LO https://github.com/hypriot/flash/releases/download/2.7.0/flash &> /dev/null
  chmod ugo+x flash
  cd ..
fi

IMAGE="ubuntu-20.04.1-preinstalled-server-arm64+raspi.img"
if [ -r ./packages/${IMAGE} ]
then
  [ -n "${VERBOSE}" ] && echo "  Ubuntu 20.04 image found"
else
  [ -n "${VERBOSE}" ] && echo "  Ubuntu 20.04 image not found: downloading"
  mkdir -p packages
  cd packages || exit 1
  curl -LO https://cdimage.ubuntu.com/releases/20.04/release/${IMAGE}.xz &> /dev/null
  [ -n "${VERBOSE}" ] && echo "  Unpacking Ubuntu 20.04 image"
  unxz ${IMAGE}.xz
  cd ..
fi

if [ -n "${DEVICE}" ]
then
  echo ""
  echo "Please insert the sd drive into ${DEVICE}"
  echo "This drive WILL BE OVERWRITTEN with the data for ${HOST}"
  read -n 1 -s -r -p "Press any key to continue (Ctrl-c to abort)"
  sudo flash --device "${DEVICE}" --force --file ~/dev/pikube/configuration/network-config --userdata ./configuration/user-data-"${HOST}" ./packages/"${IMAGE}"
else
  echo "Device for flashing not specified"
  exit 1
fi
}
#
# Start of the script itself
#

if [ "${HELP}" = "YES" ]
then
  print_help
fi

# Iterate through known ECDSA keys
#KNOWN_NODES=$(ls certificates/id_ecdsa-* | grep -v ".pub" | sed s/"certificates\/id_ecdsa-"//)

# If no nodes are specified as cli options, we read them from the "nodes" file
if [ -z "${NODES}" ]
then
  [ -n "${VERBOSE}" ] && echo "Reading nodes from file"
  NODES=$(cat nodes)
fi

for HOST in ${NODES}
do
  [ -n "${VERBOSE}" ] && echo "Working on node: ${HOST}"

  if [ -n "${ALLTASKS}${KEYS}" ]
  then
    generate_ssh_server_keys
    add_key_to_known_hosts
  fi

  if [ -n "${ALLTASKS}${FLASH}" ]
  then
    flash_image_to_drive
  fi

done
