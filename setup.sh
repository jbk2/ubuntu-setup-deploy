#!/usr/bin/env bash
set -euo pipefail

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh

# ----------------------------------------

INFO="\033[0;32m"  # Green
SUCCESS="\033[1;32m"  # Green bold
ALERT="\033[0;34m"    # Blue
WARNING="\033[0;33m"  # Yellow
ERROR="\033[0;31m"    # Red
NC="\033[0m"          # No color

# ----------------------------------------

USAGE="
##################################
Usage:
  $0
  $0 -u UNIT -s STEP

Options:
  -u UNIT    run only a given unit ("update_upgrade", "create_user", "install_nginx")
  -s STEP    run only a given step ("update", "upgrade", "add_user", "setup_ssh", "add_user_to_sudo")
  -v         run in verbose mode
  -h         show this help message
##################################
"

# ----------------------------------------

RUN_UNIT=""
RUN_STEP=""
VERBOSE=false

# each UNIT or STEP value must be defined in the corresponding array
# to enabling correct parsing of command line arguments:
valid_units=("update_upgrade" "create_user" "install_nginx")
valid_steps=("update" "upgrade" "add_user" "setup_ssh" "add_user_to_sudo" "install_nginx")

function contains_element {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

while getopts ":u:s:vh" opt; do
  case $opt in
    u)
      if contains_element "$OPTARG" "${valid_units[@]}"; then
        RUN_UNIT=$OPTARG
      else
        echo -e "${ERROR}Invalid unit specified: $OPTARG. Valid units are: ${valid_units[*]}.${NC}"
        echo -e "$USAGE"
        exit 1
      fi
      ;;
    s)
      if contains_element "$OPTARG" "${valid_steps[@]}"; then
        RUN_STEP=$OPTARG
      else
        echo -e "${ERROR}Invalid step specified: $OPTARG. Valid steps are: ${valid_steps[*]}.${NC}"
        echo -e "$USAGE"
        exit 1
      fi
      ;;
    v)
      VERBOSE=true;;
    h)
      echo -e "$USAGE"
      exit 0;;
    \?)
      echo -e "${ERROR}$OPTARG is not a valid option.${NC}"
      echo -e "$USAGE"
      exit 1;;
  esac
done

# ----------------------------------------

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
ssh_as_ubuntu <<-STDIN || echo -e "${ERROR}Updating packages${NC}"
  sudo apt update && echo -e "${SUCCESS}successfully updated packages${NC}" || echo -e "${ERROR}failed to update packages${NC}"
STDIN
fi

STEP=upgrade
if should_run; then
ssh_as_ubuntu <<-STDIN || echo -e "${ERROR}Ugrading packages${NC}"
  sudo apt upgrade -y && echo -e "${SUCCESS}successfully upgraded packages${NC}" || echo -e "${ERROR}failed to upgrade packages${NC}"
STDIN
fi

# ----------------------------------------


UNIT=create_user
STEP=add_user
if should_run; then
ssh_as_ubuntu <<-STDIN || echo -e "${ERROR}Adding $USER${NC}"
  echo -e "${SUCCESS}Attempting to add user $USER...${NC}"
  if id "$USER" &>/dev/null; then
    echo -e "${INFO}$USER already exists.${NC}"
  else
    sudo useradd -m $USER && echo -e "${SUCCESS}$USER added successfully.${NC}" \
      || echo -e "${ERROR}Failed to add $USER${NC}"
  fi
STDIN
fi

STEP=setup_ssh
if should_run; then
ssh_as_ubuntu <<-STDIN || echo -e "${ERROR}Setting up $USER's ssh key${NC}"
  echo -e "${INFO}Begining the set up of SSH environment for $USER...${NC}"

  # create ~/.ssh
  if sudo [ -d "/home/$USER/.ssh" ]; then
    echo -e "${INFO}/home/$USER/.ssh already exists for $USER${NC}"
  else
    sudo -u $USER bash -c 'mkdir ~/.ssh' && echo -e "${SUCCESS}made $USER's ~/.ssh successfully.${NC}" \
      || echo -e "${ERROR}Failed to mmkdir ~/.ssh for $USER${NC}"
  fi

  # create ~/.ssh/authorized_keys
  if sudo [ -f "/home/$USER/.ssh/authorized_keys" ]; then
    echo -e "${INFO}/home/$USER/.ssh/authorized_keys already exists for $USER${NC}"
  else
    sudo -u $USER bash -c 'touch ~/.ssh/authorized_keys' && echo -e "${SUCCESS}created $USER's ~/.ssh/authorized_keys file successfully.${NC}" \
      || echo -e "${ERROR}Failed to create ~/.ssh/authorized_keys file for $USER${NC}"
  fi

  # save ubuntu's keys into user's & chmod .ssh & authorized_keys
  sudo bash -c "cat /home/ubuntu/.ssh/authorized_keys > /home/$USER/.ssh/authorized_keys" \
    && echo -e "${SUCCESS}saved ubuntu user's authorized_keys into /home/$USER/.ssh/authorized_keys${NC}" \
    || echo -e "${ERROR}Failed to save key into /home/$USER/.ssh/authorized_keys${NC}"

  sudo chmod 700 /home/$USER/.ssh && echo -e "${SUCCESS}successfully chmod'd /home/$USER/.ssh${NC}" \
    || echo -e "${ERROR}failed to chmod /home/$USER/.ssh${NC}"

  sudo chmod 600 /home/$USER/.ssh/authorized_keys && echo -e "${SUCCESS}successfully chmod'd /home/$USER/.ssh/authorized_keys${NC}" \
    || echo -e "${ERROR}failed to chmod /home/$USER/.ssh/authorized_keys${NC}"
STDIN
fi


STEP=add_user_to_sudo
if should_run; then
ssh_as_ubuntu <<-STDIN || echo -e "${ERROR}Adding $USER to sudo group${NC}"
  # would be the 'wheel' group on Fedora/CentOS/RHEL, but is 'sudo' group in Debian.
  if groups $USER | grep -qw sudo; then
    echo -e "${INFO}$USER already a member of sudo group${NC}"
  else
    sudo usermod -a -G sudo $USER && echo -e "${SUCCESS}added $USER to the 'sudo' group${NC}" \
      || echo -e "${ERROR}failed to add $USER to sudo group${NC}"
  fi

  if grep -Fxq "deploy ALL=(ALL) NOPASSWD:ALL" /etc/sudoers.d/deploy_user_permissions; then
    echo -e "${INFO}$USER already has 'no password' set for sudo group${NC}"
  else
    echo -e "deploy ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/deploy_user_permissions \
      && echo -e "${SUCCESS}successfully added $USER to /etc/sudoers.d/{$USER}_user_permissions${NC}" \
      || echo -e "${ERROR}failed to add $USER to /etc/sudoers.d/${USER}_user_permissions${NC}"
  fi

  echo -e "${INFO}setting $USER's shell to /bin/bash${NC}"
  bash -c "sudo chsh -s /bin/bash ${USER}" && echo -e "${SUCCESS}changed shell to bash for $USER${NC}" \
    || echo -e "${ERROR}failed to change shell to bash for $USER${NC}"
STDIN
fi

# STEP=lock_root_user
# ssh_as_ubuntu <<-STDIN || echo -e "Locking $USER account"
# passwd -l $USER # don't want to lock 'ubuntu' user, but if this were 'root' user, as it would be on RedHat, we would want to.

# Don't want to lock 'ubuntu' user, but if default user were 'root' user, as it would be on RedHat, we would want to lock it.
# ssh_as_user <<-STDIN || echo -e "Disabling root"
#   chage -E o root
# STDIN

#  ----------------------------------------

UNIT=install_nginx
STEP=install_nginx
if should_run; then
ssh_as_user <<-STDIN
  if which nginx &>/dev/null; then
    echo -e "${INFO}Nginx is already installed${NC}"
    if service nginx status | grep -q "running"; then
      echo -e "${SUCCESS}Nginx is running.${NC}"
    else
      echo -e "${WARNING}Nginx is \033[4mnot${NC} running.${NC}"
    fi
  else
    sudo apt install -y nginx && echo -e "${SUCCESS}successfully installed nginx${NC}" \
      || echo -e "${ERROR}failed to install nginx${NC}"
  fi
STDIN
fi