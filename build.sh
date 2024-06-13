#!/bin/bash

USER=ubuntu
SERVER=$SERVER
PORT=22 # default ssh port
SSH_KEY=$SSH_KEY
SSH_OPTIONS="-i $SSH_KEY -o StrictHostKeyChecking=no"
SSH_ARGS="$USER@$SERVER -p $PORT $SSH_OPTIONS"
SCP_ARGS="-i $SSH_KEY"

#Debug output
echo "Connecting to $USER@$SERVER on port $PORT using SSH key $SSH_KEY"

ssh $SSH_ARGS 'bash -s' <<-STDIN
# set bash session options to catch errors
set -euo pipefail

# Install nginx
sudo apt install -y nginx
STDIN

DIR=$(dirname "$(realpath "$0")")
echo " here's the directory we're in and are copying index from; $DIR"
if [ -e $DIR/index.html ]
  scp $SCP_ARGS $DIR/index.html $USER@$SERVER:~/index.html && echo "successfully copied ~/index to server"
else
  echo "This script needs $DIR/index.html to exist, which it currently does not"
  exit 1
fi


ssh $SSH_ARGS 'bash -s' <<-STDIN
  set -euo pipefail
  # Move the file to the nginx html directory
  sudo mv ~/index.html /var/www/html/index.html && echo "successfully moved ~/index to /var/www/html/"
  sudo systemctl restart nginx.service && echo "successfully restarted nginx"
STDIN
