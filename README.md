### README.md
This repository contains multiple script files, for deployment to an Ubuntu Linux distribution,
which will:

- from running the ./setup.sh executable script file:
  - ssh in as 'ubuntu' into the remote server
  - create a user (recommend naming user as 'deploy') with sudo & no password-all privelidges
  - install Nginx

- from running the ./deploy.sh executable script file:
  - copy the local ./index.html file to 'deploy' users' home
  - move the ~/index.html file to /var/www/html
  - change the ownership of the /var/www/html/index.html file to 'ubuntu'
  - restart the nginx service

### To run the scripts:
1. clone the repository
2. cd into the repository
3. run the help option on ./setup.sh, i.e. `./setup.sh -h`
  - run without arguments to run all units and steps; `USER=deploy ./setup.sh`
  - you must set USER to the username that you want to run the server
    set up with, and you must pass this USER varible in the command line
    argument, otherwise USER will be set to your local machine's user name.
4. then run the `USER=deploy ./deploy.sh` script file in terminal
  - you must pass USER in with the execute deploy.sh command (set as
    the same user that you setup in setup.sh).
  - you must have an index.html file in the same directory as the deploy.sh
    script file - this is the html file that you are deploying to the server.