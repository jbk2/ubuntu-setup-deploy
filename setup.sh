#!/usr/bin/env bash
set -euo pipefail
set -x

DIR=`dirname "$(readlink -f "$0")"`
source $DIR/settings.sh

ssh_as_ubuntu <<-STDIN || fail "Adding user & setting up ssh keys"
  echo "Attempting to add user $USER..."
  sudo useradd -m $USER && echo "$USER added successfully." || fail "Failed to add $USER"
  
  echo "Setting up SSH environment for $USER..."
  sudo -u $USER bash -c 'mkdir ~/.ssh' && echo "made $USER's ~/.ssh successfully." \
    || fail "Failed to mmkdir ~/.ssh for $USER"

  sudo -u $USER bash -c 'touch ~/.ssh/authorized_keys' && echo "made $USER's ~/.ssh/authorized_keys file successfully." \
    || fail "Failed to create ~/.ssh/authorized_keys file for $USER"

  sudo bash -c "cat /home/ubuntu/.ssh/authorized_keys > /home/$USER/.ssh/authorized_keys" \
   && echo "saved authorized_key into /home/$USER/.ssh/authorized_keys" \
    || fail "Failed to save key into /home/$USER/.ssh/authorized_keys"

  sudo chmod 700 /home/$USER/.ssh && echo "successfully chmod'd /home/$USER/.ssh" \
    || fail "failed to chmod /home/$USER/.ssh"

  sudo chmod 600 /home/$USER/.ssh/authorized_keys && echo "successfully chmod'd /home/$USER/.ssh/authorized_keys" \
    || fail "failed to chmod /home/$USER/.ssh/authorized_keys"

# would be the 'wheel' group on Fedora/CentOS/RHEL, but is 'sudo' group in Debian.
  sudo usermod -a -G sudo $USER && echo "added $USER to the 'sudo' group" \
    || fail "failed to add $USER to sudo group"

  echo "deploy ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/deploy_user_permissions \
    && echo "successfully added $USER to /etc/sudoers.d/$USER_user_permissions" \
    || fail "failed to add $USER to /etc/sudoers.d/$USER_user_permissions"

# passwd -l $USER # don't want to lock 'ubuntu' user, but if this were 'root' user, as it would be on RedHat, we would want to.
STDIN

# Don't want to lock 'ubuntu' user, but if default user were 'root' user, as it would be on RedHat, we would want to lock it.
# ssh_as_user <<-STDIN || fail "Disabling root"
#   chage -E o root
# STDIN

ssh_as_user <<-STDIN
  sudo apt install -y nginx && echo "successfully installed nginx" || fail "failed to install nginx"
STDIN