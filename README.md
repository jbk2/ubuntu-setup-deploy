## README.md
_Last updated: `2024-07-17 16:57:29`_

This repo contains script files, for deployment on a Debian Ubuntu Linux distribution
to carry out the following:

- on running the ./setup.sh executable script file:
  - ssh's in as 'ubuntu' into the remote server.
  - creates a user (recommend naming user as 'deploy') with sudo & no password-all privelidges.
  - installs Nginx.
  - creates a systemd unit file to run the update-dns.sh script on each restart.

- on running the ./deploy.sh executable script file:
  - copies the local ./index.html file to 'deploy' users' home
  - moves the ~/index.html file to /var/www/html
  - changes the ownership of the /var/www/html/index.html file to 'ubuntu'
  - restarts the nginx service


## To run the scripts:
1. clone the repository
2. cd into the repository
3. update $SERVER with host's public ip in settings.sh
4. run the help option on ./setup.sh, i.e. `./setup.sh -h`
  - run without arguments to run all units and steps; `USER=deploy ./setup.sh`
  - when executing the script files you must define the USER variable, with the
    username that you wish to create on the server and run deployment from,
    otherwise USER will be set to your local machine's user name.
5. then run the `USER=deploy ./deploy.sh` script file in terminal
  - you must pass USER in with the execute deploy.sh command (set as
    the same user that you setup in setup.sh).
  - you must have an index.html file in the same directory as the deploy.sh
    script file - this is the html file that you are deploying to the server.


## MANUAL SETUP REQUIRED:
### HTTPS
- To serve via https, you must manually configure the server to do so, by doing the following:
	1. Get SSL cert & key from provider.
	2. create an /etc/nginx/ssl directory.
  3. scp cert & key into server:
    - cert; `scp -i ~/path/to/your/ssh-keypair.pem ~/path/to/your/ssl_certificate.crt ubuntu@13.36.100.115:/home/ubuntu`
    - key; `scp -i ~/path/to/your/ssh-keypair.pem ~/path/to/your/ssl_certificate_key.key ubuntu@13.36.100.115:/home/ubuntu`
  4. sudo move the cert & key into /etc/nginx/ssl directory:
      i.e. `sudo mv ~/ssl_certificate.crt /etc/nginx/ssl/ssl_certificate.crt`
      i.e. `sudo mv ~/ssl_certificate_key.key /etc/nginx/ssl/ssl_certificate_key.key`
  5. chmod & chown to nginx user, default user set in /etc/nginx/nginx.conf, usually 'www-data':
    - `sudo chmod 600 /etc/nginx/ssl/ssl_certificate_key.key`
    - `sudo chown www-data:www-data /etc/nginx/ssl/ssl_certificate_key.key`
  6. Update server context in /etc/nginx/sites-available/... with:
    - ssl_certificate /path/to/cert
    - ssl_certificate_key /path/to/cert_key
    - root /path/to/your/html
    - define your location route contexts
    see example of a server context setup for ssl in this repo; 'nginx/sites-available/default

### DNS _(via cloudflare)_
- To assign a domain name to the EC2 instance you must:
  1. Initially, manually create 2 DNS 'A records' pointing to the EC2 instance's public IP address:
    - one named; 'www'
    - one named; 'domain_name.tld'
  2. Update the variable values in the ./dns-update.sh with:
    - cloudflare api token for domain (via https://dash.cloudflare.com/profile/api-tokens)
    - domain's cloudflare zone - get value from cloudflare api at below endpoint:
    `curl -X GET "https://api.cloudflare.com/client/v4/zones" -H "Authorization: Bearer YOUR_API_TOKEN" -H "Content-Type: application/json"`
    - the dns record(s) name and id - get value from cloudflare api at below endpoint:
    `curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records" -H "Authorization: Bearer YOUR_API_TOKEN" -H "Content-Type: application/json"`
  3. Ensure that the setup.sh script unit named 'auto_update_dns' has run, after the dns-update.sh variables values are updated.
  4. ssh into the server (update ~/.ssh/config for easy ssh login with the EC2 instance's public ip, delete old 'known hosts') and run `systemctl status dns_update.service` to check that the systemd service has been created (it should be loaded and enabled, but inactive because it only runs on restart). If systemd service created successfully, then the DNS records will be now be automatically updated via cloudflare's API on each server restart.