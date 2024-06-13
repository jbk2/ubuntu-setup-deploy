#!/bin/bash

USER=ubuntu
SERVER=$SERVER
PORT=22 # default ssh port
SSH_KEY=$SSH_KEY
SSH_OPTIONS="-i $SSH_KEY -o StrictHostKeyChecking=no"
SSH_ARGS="$USER@$SERVER -p $PORT $SSH_OPTIONS"
SCP_ARGS="-i $SSH_KEY"

fail() {
  echo "Failed: $1"
  exit 1
}

#Debug output
echo "Connecting to $USER@$SERVER on port $PORT using SSH key $SSH_KEY"

ssh $SSH_ARGS 'bash -s' <<-STDIN
# set bash session options to catch errors
set -euo pipefail

# Install nginx
sudo apt install -y nginx && echo "successfully installed nginx" || fail "failed to install nginx"
STDIN

DIR=$(dirname "$(realpath "$0")")
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


ssh $SSH_ARGS 'bash -s' <<-STDIN
  set -euo pipefail

  # Move the file to the nginx html directory
  if ! sudo mv ~/index.html /var/www/html/index.html
  then 
    fail "failed to move ~/index to /var/www/html/"
  else
    echo "successfully moved ~/index to /var/www/html/"
  fi

  # Restart nginx to apply changes
  if ! sudo systemctl restart nginx.service
  then
    fail "failed to restart nginx"
  else
    echo "successfully restarted nginx"
  fi
STDIN
