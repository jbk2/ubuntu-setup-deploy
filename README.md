### README.md

This repository contains multiple script files, for deployment to an Ubuntu Linux distribution,
which will:
- from running the ./setup.sh executable script file:
  - ssh in as 'ubuntu' into the remote server
  - create 'deploy' user with sudo, no password-all, privelidges
  - install nginx
- from the deploy.sh script file:
  - copy the local ./index.html file to 'deploy' users' home
  - move the ~/index.html file to /var/www/html
  - change the ownership of the /var/www/html/index.html file to 'ubuntu'
  - restart the nginx service

### To run the scripts:
- clone the repository
- cd into the repository
- simply run the ./setup.sh script file in terminal
- then run the ./deploy.sh script file in terminal