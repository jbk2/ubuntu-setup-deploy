#!/usr/bin/env bash
set -euo pipefail
DIR=$(dirname "$(realpath "$0")")
source $DIR/settings.sh
SCP_ARGS="-i $SSH_KEY"
VERBOSE=false
echo -e "${INFO}here's the directory we're in and are copying index from; $DIR${NC}"

# ----------------------------------------

while getopts ":v" opt; do
  case $opt in
    v)
      VERBOSE=true;;
    \?)
      echo -e "${ERROR}$OPTARG is not a valid option.${NC}"
      exit 1;;
  esac
done

if [ "$VERBOSE" = "true" ]; then
  set -x  # Enable debugging output
fi

# ----------------------------------------

if [ -e $DIR/index.html ]
then
  echo -e "${SSH_KEY}"
  if scp $SCP_ARGS $DIR/index.html $USER@$SERVER:~/index.html
  then
    echo -e "${SUCCESS}successfully scp'd ~/index to server${NC}"
  else
    echo -e "${ERROR}failed to copy ~/index to server${NC}"
  fi
else
  echo -e "${ERROR}This script needs $DIR/index.html to exist, which it currently does not${NC}"
fi

ssh_as_user <<-STDIN
  # Move the file to the nginx html directory
  if sudo mv ~/index.html /var/www/html/index.html
  then 
    echo -e "${SUCCESS}successfully moved ~/index to /var/www/html/${NC}"
  else
    echo -e "${ERROR}failed to move ~/index to /var/www/html/${NC}"
  fi

  # change owner of copied index from local machine owner to ubuntu user
  if sudo chown ubuntu:ubuntu /var/www/html/index.html
  then
    echo -e "${SUCCESS}successfully changed ownership of /var/www/html/index.html to ubuntu user${NC}"
  else
    echo -e "${ERROR}failed to change ownership of /var/www/html/index.html to ubuntu${NC}"
  fi

  # Restart nginx to apply changes
  if sudo systemctl restart nginx.service
  then
    echo -e "${SUCCESS}successfully restarted nginx${NC}"
  else
    echo -e "${ERROR}failed to restart nginx${NC}"
  fi
STDIN
