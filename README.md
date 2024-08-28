## README.md
_Last updated: `2024-08-28 20:39:04`_

**On server restart - manually update the new public ipv4 into your local ~/.ssh/config for ease of ssh'ing into server** 

This repo contains scripts for auto set up of and deployment to a Linux Debian Ubuntu distribution,
to carry out the following:

- on running the ./setup.sh executable script file:
  - ssh's into, as 'ubuntu' user, the remote server.
  - creates a user (recommend naming user as 'deploy') with sudo & no password-all privelidges.
  - installs Nginx.
  - creates a systemd unit file to run the update-dns.sh script on each restart.

- on running the ./deploy.sh executable script file:
  - copies the local ./index.html file to 'deploy' users' home directory.
  - moves the ~/index.html file to /var/www/html.
  - changes the ownership of the /var/www/html/index.html file to 'ubuntu'.
  - restarts the nginx service.

- the index.html file is manually written based upon the copy from this README.md. To ensure content 
  parity both files are programatically timestamped via:
  - For index.html a script element in deploy.sh lines 30-51.
  - For README.md via a .git/hooks/pre-commit which instantiates the ./update_readme.sh script.


## Variable Configuration
The below **sensitive** variables must be defined for these scripts to operate. Create a /.env file with the correct values for the following variables:

In `/.env`:
| Variable | Description                              |
|----------|------------------------------------------|
| `SERVER` | Virtual machine public IP |
| `SERVER_NAME` | Domain name (with correct DNS settings defined) |
| `USER` | Name for the user that will replace *ubuntu* for administration |
| `SSH_KEY` | Path to the private SSH key |
| `CF_API_TOKEN` | CloudFlare API token with the assigned domain's DNS editing permissions |
| `ZONE_ID` | The zone id of the assigned domain name |
| `RECORD_ID` | The DNS record ID number that needs updating on restart |
| `RECORD_NAME` | The DNS record name number that needs updating on restart |

/settings.sh will then source your /.env file and export it's variable values to it's runtime environment for the scripts to use. /settings.sh also defines some non-sensitive variables values that the scripts may use.


## To run the scripts:
1. clone the repository
2. cd into the repository
3. Create a local /.env and populate with correct values for variables listed in the configuration table above.
4. Setup; run `./setup.sh -h` in terminal and read ./setup.sh's help options:
  - run `USER=deploy ./setup.sh` in terminal (without arguments runs all units & steps)
  - you must define USER variable in terminal commands with the username that you wish
  to create on the server and run deployment from, otherwise USER will be set to your
  local machine's user name!
5. Deploy index.html; run `USER=deploy ./deploy.sh` in terminal to execute the deploy script.
  - again, you must define USER in the terminal execute command (set as the same user
    that you setup in setup.sh).
  - you must have an index.html file in the same directory as the deploy.sh script file - this is the HTML file that you are deploying to the server.


## MANUAL CONFIGURATION REQUIRED:
### HTTPS
- To serve via https, you must manually configure the server to do so, by doing the following:
	1. Get SSL cert & key from provider.
	2. create an /etc/nginx/ssl directory.
  3. scp cert & key into server:
    - cert; `scp -i ~/path/to/your/ssh-keypair.pem ~/path/to/your/ssl_certificate.crt ubuntu@12.34.567.890:/home/ubuntu`
    - key; `scp -i ~/path/to/your/ssh-keypair.pem ~/path/to/your/ssl_certificate_key.key ubuntu@12.34.567.890:/home/ubuntu`
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
  2. Update the DNS variable values in your .env with:
    - cloudflare api token for domain (via https://dash.cloudflare.com/profile/api-tokens)
    - domain's cloudflare zone - get value from cloudflare api at below endpoint:
    `curl -X GET "https://api.cloudflare.com/client/v4/zones" -H "Authorization: Bearer YOUR_API_TOKEN" -H "Content-Type: application/json"`
    - the dns record(s) name and id - get value from cloudflare api at below endpoint:
    `curl -X GET "https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records" -H "Authorization: Bearer YOUR_API_TOKEN" -H "Content-Type: application/json"`
  3. Ensure that the setup.sh script unit named 'auto_update_dns' has run, after your .env cloudflare related variable values are updated.
  4. ssh into the server (update ~/.ssh/config for easy ssh login with the EC2 instance's public ip, delete old 'known hosts') and run `systemctl status dns-update.service` to check that the systemd service has been created (it should be loaded and enabled, but inactive because it only runs on restart). If systemd service created successfully, then the DNS records will be now be automatically updated via cloudflare's API on each server restart.

  ### Documentation
  - SERVER_INFO.md file contains server instance info and is saved on server instance at /etc/docs/SERVER_INFO.md