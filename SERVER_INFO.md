# Server Documentation for SERVER_NAME

- This file, /etc/docs/SERVER_INFO.md, is where info about this server instance will be stored.

## General Information
- **Purpose**: A demonstration of an Ubuntu instance setup with my 'ubuntu-setup-deploy' script, whose repo can be found [here](https://github.com/jbk2/ubuntu-setup-deploy)
- **Public ipv4**: 13.39.86.143 (changes on every EC2 instance restart)
- **Domain Name**: currently DNS linked to www.ctrlaltinsure.com (via CloudFlare)
- **OS**: Ubuntu 20.04.4 LTS
- **EC2 Instance Type** t4g.nano
- **Architecture**: ARM64
- **Region**: eu-west-3 (Paris)
- **Hostname**: ip-172-31-46-114.eu-west-3.compute.internal
- **AWS ami id**: ami-035e217195261eb8e

## Installed Software
- nginx 1.24.0
- ruby 3.3.3
- redis-server 7.0.15
- postgresql 16.3

## Services Running
- HTTP Server on port 80
- SSH server on port 22

## Configuration Changes
- `/etc/nginx/nginx.conf` modified to include custom settings.
- `nginx/sites-enabled/default` defines the default server block.
- Nginx configured to redirect ports 80 to ssl port 443.

## Maintenance Notes
- System updates every ...? - not automated.
- Daily backups at ...? - not authomated.

## Helpful Commands
- `sudo su - postgres -c psql`
- `sudo systemctl status nginx`, `sudo systemctl status dns-update`, ``
- 

## Contact
- **Admin**: James Kemp, james@bibble.com
