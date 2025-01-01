# PHP-ef-installers
PHP-EF Installation methods for the installation of PHP-EF from the following repository: 
[Mat Cox Repo](https://github.com/TehMuffinMoo/php-ef)


# Installation Script for PHP-ef

The following Script will install Docker-CE/Docker Compose and make all relevant changes/customisations.

## Supported OS currently are:
- Oracle Linux 9
- RHEL 9
- Debian
- Ubuntu (22.04+24.04)

Use the following script to install PHP-ef on your server:

```bash
# Step 1: Download the script
curl -fsSL https://raw.githubusercontent.com/tinytechlabuk/php-ef-installers/main/Installing-php-ef.sh -o install.sh

# Step 2: Make it executable and run it
chmod +x install.sh && ./install.sh
```


## Note that the script will autogenerate HWID and Security Salt for the Installation:
- Security Salt
- HWID

## Default credentials for the installation are:
### Username:
```
admin
```

### Password:
```
Admin123!
```

## Automation tools installation for PHP-ef
If you want to deploy PHP-ef using automation tools such as Ansible, you can use the following YAML file:

Oracle Linux 9:
[View the DockerCE_InfraPortal_Install.yml file](https://github.com/tinytechlabuk/php-ef-installers/blob/main/DockerCE_InfraPortal_Install.yml)

RHEL 9:
[View the DockerCE_InfraPortal_Install.yml file](https://github.com/tinytechlabuk/php-ef-installers/blob/main/DockerCE_InfraPortal_Install.yml)


Debian 11:
[View the DockerCE_InfraPortal_Install.yml file](https://github.com/tinytechlabuk/php-ef-installers/blob/main/DockerCE_InfraPortal_Install.yml)  

Ubuntu 22.04:
[View the DockerCE_InfraPortal_Install.yml file](https://github.com/tinytechlabuk/php-ef-installers/blob/main/DockerCE_InfraPortal_Install.yml)

For direct use, you can fetch it using the raw file link:

```bash
curl -O https://raw.githubusercontent.com/tinytechlabuk/php-ef-installers/main/DockerCE_InfraPortal_Install.yml

