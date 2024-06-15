#!/usr/bin/env bash
set -euo pipefail

SCP_ARGS="-i $SSH_KEY"
DIR=$(dirname "$(realpath "$0")")
source $DIR/settings.sh
echo " here's the directory we're in and are copying index from; $DIR"

if [ -e $DIR/index.html ]
then
  if scp $SCP_ARGS $DIR/index.html $USER@$SERVER:~/index.html
  then
    echo "successfully scp'd ~/index to server"
  else
    fail "failed to copy ~/index to server"
  fi
else
  fail "This script needs $DIR/index.html to exist, which it currently does not"
fi

ssh_as_user <<-STDIN
  # Move the file to the nginx html directory
  if sudo mv ~/index.html /var/www/html/index.html
  then 
    echo "successfully moved ~/index to /var/www/html/"
  else
    fail "failed to move ~/index to /var/www/html/"
  fi

  # change owner of copied index from local machine owner to ubuntu user
  if sudo chown ubuntu:ubuntu /var/www/html/index.html
  then
    echo "successfully changed ownership of /var/www/html/index.html to ubunut user"
  else
    fail "failed to change ownership of /var/www/html/index.html to ubuntu"
  fi

  # Restart nginx to apply changes
  if ! sudo systemctl restart nginx.service
  then
    fail "failed to restart nginx"
  else
    echo "successfully restarted nginx"
  fi
STDIN
