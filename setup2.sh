#!/usr/bin/env bash
set -euo pipefail

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh


# ----------------------------------------

SUCCESS="\033[0;32m"  # Green
ALERT="\033[0;34m"    # Blue
WARNING="\033[0;33m"  # Yellow
ERROR="\033[0;31m"    # Red
NC="\033[0m"          # No color

# ----------------------------------------

USAGE="
Usage:
  $0 (runs all UNITs & STEPs)
  $0 -u UNIT -s STEP
Options:
  -u UNIT    run only a given unit
  -s STEP    run only a given step
  -v         run in verbose mode
  -h         show this help message"

# ----------------------------------------

RUN_UNIT=""
RUN_STEP=""
VERBOSE=false

# assign variables from command line arguments
while getopts ":u:s:vh" opt; do
  case $opt in
    u)
      RUN_UNIT=$OPTARG;;
    s)
      RUN_STEP=$OPTARG;;
    v)
      VERBOSE=true;;
    h)
      echo -e "$USAGE"
      exit 0;;
    \?)
      echo -e "$OPTARG is not a valid option."
      echo -e "$USAGE"
      exit 1;;
  esac
done

if [ "$VERBOSE" = "true" ]; then
  set -x  # Enable debugging output
fi

should_run() {
  # No unit and no step specified
  if [ -z "$RUN_UNIT" ] && [ -z "$RUN_STEP" ]; then
    return 0  # True, run all
  fi

  # Specific unit, no step specified
  if [ "$RUN_UNIT" = "$UNIT" ] && [ -z "$RUN_STEP" ]; then
    return 0  # True, run all steps in the specified unit
  fi

  # No unit, specific step specified
  if [ -z "$RUN_UNIT" ] && [ "$RUN_STEP" = "$STEP" ]; then
    return 0  # True, run the specified step in all units
  fi

  # Specific unit and specific step specified
  if [ "$RUN_UNIT" = "$UNIT" ] && [ "$RUN_STEP" = "$STEP" ]; then
    return 0  # True, run the specified step in the specified unit
  fi

  return 1  # False, do not run
}


# ----------------------------------------

UNIT=update_upgrade
STEP=update
if should_run; then
ssh_as_ubuntu <<-STDIN || fail "${ERROR}Updating packages${NC}"
  sudo apt update && echo -e "${SUCCESS}successfully updated packages${NC}" || fail "${ERROR}failed to update packages${NC}"
STDIN
fi

STEP=upgrade
if should_run; then
ssh_as_ubuntu <<-STDIN || fail "${ERROR}Ugrading packages${NC}"
  sudo apt upgrade -y && echo -e "${SUCCESS}successfully upgraded packages${NC}" || fail "${ERROR}failed to upgrade packages${NC}"
STDIN
fi

# ----------------------------------------


UNIT=create_user
STEP=add_user
if should_run; then
ssh_as_ubuntu <<-STDIN || fail "${ERROR}Adding $USER${NC}"
  echo -e "${SUCCESS}Attempting to add user $USER...${NC}"
  if id "$USER" &>/dev/null; then
    echo -e "${ALERT}$USER already exists.${NC}" 
  else
    sudo useradd -m $USER && echo -e "${SUCCESS}$USER added successfully.${NC}" || fail "${ERROR}Failed to add $USER${NC}"
  fi
STDIN
fi

valid_key_found=false
pubkey=""
STEP=setup_ssh
if should_run; then
ssh_as_ubuntu <<-STDIN || fail "${ERROR}Setting up $USER's ssh key${NC}"
  echo -e "${SUCCESS}Begining the set up of SSH environment for $USER...${NC}"

  # create ~/.ssh
  if [ -d "/home/$USER/.ssh" ]; then
    echo -e "${ALERT}/home/$USER/.ssh already exists for $USER${NC}"
  else
    sudo -u $USER bash -c 'mkdir ~/.ssh' && echo -e "${SUCCESS}made $USER's ~/.ssh successfully.${NC}" \
      || fail "${ERROR}Failed to mmkdir ~/.ssh for $USER${NC}"
  fi

  # create ~/.ssh/authorized_keys
  if [ -f "/home/$USER/.ssh/authorized_keys" ]; then
    echo -e "${ALERT}/home/$USER/.ssh/authorized_keys already exists for $USER${NC}"
  else
    sudo -u $USER bash -c 'touch ~/.ssh/authorized_keys' && echo -e "${SUCCESS}made $USER's ~/.ssh/authorized_keys file successfully.${NC}" \
      || fail "${ERROR}Failed to create ~/.ssh/authorized_keys file for $USER${NC}"
  fi

  # cmod of ./ssh and ./ssh/authorized_keys to 700 & 600 respectively
  sudo chmod 700 /home/$USER/.ssh && echo -e "${SUCCESS}successfully chmod'd /home/$USER/.ssh${NC}" \
    || fail "${ERROR}failed to chmod /home/$USER/.ssh${NC}"

  sudo chmod 600 /home/$USER/.ssh/authorized_keys && echo -e "${SUCCESS}successfully chmod'd /home/$USER/.ssh/authorized_keys${NC}" \
    || fail "${ERROR}failed to chmod /home/$USER/.ssh/authorized_keys${NC}"


  # if file is present and not empty check each key's validity, if none valid copy valid one from ubuntu user
  if [ -f "/home/$USER/.ssh/authorized_keys" ] && [ -s "/home/$USER/.ssh/authorized_keys" ]; then
    echo -e "${ALERT}/home/$USER/.ssh/authorized_keys is not empty, checking for any key validity${NC}"    
    

    while IFS= read -r $pubkey; do
      if ! ssh-keygen -l -f <(echo "$pubkey") &>/dev/null; then
        echo -e "${WARNING}Invalid SSH key: $pubkey${NC}"
      else
        valid_key_found=true
        echo -e "${ALERT}Valid SSH key found: $pubkey${NC}"
        break
      fi
    done < "/home/$USER/.ssh/authorized_keys"

     while IFS= read -r line; do
      # Using process substitution with sudo might be tricky, may need to adjust depending on system
      if echo "$line" | sudo -u $USER ssh-keygen -l -f /dev/stdin &>/dev/null; then
        echo -e "${SUCCESS}Valid SSH key found.${NC}"
        valid_key_found=true
        break
      else
        echo -e "${ERROR}Invalid SSH key found.${NC}"
      fi
    done < <(sudo -u $USER cat "/home/$USER/.ssh/authorized_keys")

    while read -r line; do
      if ssh-keygen -l -f <(echo "$line") &>/dev/null; then
        echo "Valid SSH key found."
        valid_key_found=true
        break
      fi
    done < <(sudo -u $USER cat "/home/$USER/.ssh/authorized_keys")

    if [ "$valid_key_found" = "false" ]; then
      echo -e "${ALERT}No valid SSH key found in /home/$USER/.ssh/authorized_keys, now copying over from ubuntu user${NC}"
      sudo bash -c "cat /home/ubuntu/.ssh/authorized_keys > /home/$USER/.ssh/authorized_keys" \
        && echo -e "${SUCCESS}saved authorized_key into /home/$USER/.ssh/authorized_keys${NC}" \
        || fail "${ERROR}Failed to save key into /home/$USER/.ssh/authorized_keys${NC}"
    fi
  fi

  # if file is present but empty copy valid key from ubuntu user
  if [ -f "/home/$USER/.ssh/authorized_keys" ] && [ ! -s "/home/$USER/.ssh/authorized_keys" ]; then
  sudo bash -c "cat /home/ubuntu/.ssh/authorized_keys > /home/$USER/.ssh/authorized_keys" \
   && echo -e "${SUCCESS}saved authorized_key into /home/$USER/.ssh/authorized_keys${NC}" \
    || fail "${ERROR}Failed to save key into /home/$USER/.ssh/authorized_keys${NC}"
  fi
STDIN
fi

STEP=add_user_to_sudo
if should_run; then
ssh_as_ubuntu <<-STDIN || fail "${ERROR}Adding $USER to sudo group${NC}"
  
  if groups $USER | grep -qw sudo; then
    echo -e "${ALERT}$USER already a member of sudo group${NC}"
  else
    echo -e "${ALERT}$USER not in sudo group, adding them now...${NC}"
    # would be the 'wheel' group on Fedora/CentOS/RHEL, but is 'sudo' group in Debian.
    sudo usermod -a -G sudo $USER && echo -e "${SUCCESS}added $USER to the 'sudo' group${NC}" \
      || fail "${ERROR}failed to add $USER to sudo group${NC}"
  fi

  if grep -Fxq "deploy ALL=(ALL) NOPASSWD:ALL" /etc/sudoers.d/deploy_user_permissions; then
    echo -e "${ALERT}$USER already has sudo group no password setting${NC}"
  else
    echo -e "deploy ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/deploy_user_permissions \
      && echo -e "${SUCCESS}successfully added $USER to /etc/sudoers.d/{$USER}_user_permissions${NC}" \
      || fail "${ERROR}failed to add $USER to /etc/sudoers.d/${USER}_user_permissions${NC}"
  fi


  users_shell=$(sudo -u $USER bash -c 'echo $SHELL')
  if [ "$users_shell" = "/bin/bash" ]; then
    echo -e "${ALERT}$USER's shell is already bash${NC}"
  else
    echo -e "${ALERT}$USER's shell is not bash, setting it as bash now...${NC}"
    bash -c "sudo chsh -s /bin/bash ${USER}" && echo -e "${SUCCESS}changed shell to bash for $USER${NC}" \
      || fail "${ERROR}failed to change shell to bash for $USER${NC}"
  fi

STDIN
fi

# STEP=lock_root_user
# ssh_as_ubuntu <<-STDIN || fail "Locking $USER account"
# passwd -l $USER # don't want to lock 'ubuntu' user, but if this were 'root' user, as it would be on RedHat, we would want to.

# Don't want to lock 'ubuntu' user, but if default user were 'root' user, as it would be on RedHat, we would want to lock it.
# ssh_as_user <<-STDIN || fail "Disabling root"
#   chage -E o root
# STDIN

#  ----------------------------------------

UNIT=install_nginx
if should_run; then
  if which nginx &>/dev/null; then
    echo -e "${ALERT}Nginx is already installed${NC}"
    
    if service nginx status | grep -q "running"; then
      echo "Nginx is running."
    else
      echo "Nginx is not running."
    fi
  else
    echo -e "${ALERT}Nginx not installed, installing now...${NC}"
    ssh_as_user <<-STDIN
      sudo apt install -y nginx && echo -e "${SUCCESS}successfully installed nginx${NC}" || fail "${ERROR}failed to install nginx${NC}"
    STDIN
  fi
fi