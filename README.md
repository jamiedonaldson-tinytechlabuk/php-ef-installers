# php-ef-installers
PHP-EF Installation methods for the following repo: 
[Mat Cox Repo](https://github.com/TehMuffinMoo/php-ef)


# Installation Script for PHP-ef

The following Script will install Docker-CE/Docker Compose and make all relevant changes/customisations.

## Supported OS currently are:
- Oracle Linux 9
- RHEL 9
- Debian (22.04+24.04)

Use the following script to install PHP-ef on your server:

```bash
curl -fsSL https://raw.githubusercontent.com/jamiedonaldson-tinytechlabuk/php-ef-installers/main/Installing-php-ef.sh | bash

## Note that the script will autogenerate HWID and Security Salt for the Installation:
- Security Salt
- HWID

Default Username: admin
Default Password: Admin123!
```