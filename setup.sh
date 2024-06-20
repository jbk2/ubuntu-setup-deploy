#!/usr/bin/env bash
set -euo pipefail

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh


# ----------------------------------------

SUCCESS="\033[0;32m"  # Green
ERROR="\033[0;31m"    # Red
NC="\033[0m"          # No color

# ----------------------------------------

USAGE="
Usage:
  $0
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
      echo "$USAGE"
      exit 0;;
    \?)
      echo "$OPTARG is not a valid option."
      echo "$USAGE"
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

UNIT=update-upgrade
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


UNIT=create-user
STEP=add_user
if should_run; then
ssh_as_ubuntu <<-STDIN || fail "${ERROR}Adding $USER${NC}"
  echo -e "${SUCCESS}Attempting to add user $USER...${NC}"
  sudo useradd -m $USER && echo -e "${SUCCESS}$USER added successfully.${NC}" || fail "${ERROR}Failed to add $USER${NC}"
STDIN
fi

STEP=setup_ssh
if should_run; then
ssh_as_ubuntu <<-STDIN || fail "${Error}Setting up $USER's ssh key${NC}"
  echo -e "${SUCCESS}Setting up SSH environment for $USER...${NC}"
  sudo -u $USER bash -c 'mkdir ~/.ssh' && echo "${SUCCESS}made $USER's ~/.ssh successfully.${NC}" \
    || fail "${ERROR}Failed to mmkdir ~/.ssh for $USER${NC}"

  sudo -u $USER bash -c 'touch ~/.ssh/authorized_keys' && echo "${SUCCESS}made $USER's ~/.ssh/authorized_keys file successfully.${NC}" \
    || fail "${ERROR}Failed to create ~/.ssh/authorized_keys file for $USER${NC}"

  sudo bash -c "cat /home/ubuntu/.ssh/authorized_keys > /home/$USER/.ssh/authorized_keys" \
   && echo "${SUCCESS}saved authorized_key into /home/$USER/.ssh/authorized_keys${NC}" \
    || fail "${ERROR}Failed to save key into /home/$USER/.ssh/authorized_keys${NC}"

  sudo chmod 700 /home/$USER/.ssh && echo "${SUCCESS}successfully chmod'd /home/$USER/.ssh${NC}" \
    || fail "${ERROR}failed to chmod /home/$USER/.ssh${NC}"

  sudo chmod 600 /home/$USER/.ssh/authorized_keys && echo "${SUCCESS}successfully chmod'd /home/$USER/.ssh/authorized_keys${NC}" \
    || fail "${ERROR}failed to chmod /home/$USER/.ssh/authorized_keys${NC}"
STDIN
fi

STEP=add_user_to_sudo
if should_run; then
ssh_as_ubuntu <<-STDIN || fail "${ERROR}Adding $USER to sudo group${NC}"
# would be the 'wheel' group on Fedora/CentOS/RHEL, but is 'sudo' group in Debian.
  sudo usermod -a -G sudo $USER && echo "${SUCCESS}added $USER to the 'sudo' group${NC}" \
    || fail "${ERROR}failed to add $USER to sudo group${NC}"

  echo "deploy ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/deploy_user_permissions \
    && echo "${SUCCESS}successfully added $USER to /etc/sudoers.d/$USER_user_permissions${NC}" \
    || fail "${ERROR}failed to add $USER to /etc/sudoers.d/$USER_user_permissions${NC}"
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

UNIT=install-nginx
STEP=install_nginx
if should_run; then
ssh_as_user <<-STDIN
  sudo apt install -y nginx && echo "${SUCCESS}successfully installed nginx${NC}" || fail "${ERROR}failed to install nginx${NC}"
STDIN
fi