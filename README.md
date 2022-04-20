# High Availability Hugo Static Site

[**Read the in-depth tutorial on my website!**](https://tmclo.dev/blog/ha-hugo-stack/)

This is an example of creating a high-availability hugo cluster utilising Docker Swarm, Nginx & Traefik

The deployment of the infrastructure is managed using Terraform whilst the configuration for Docker Swarm and deploying the hugo cluster is managed with ansible.

To get started read over `main.tf` and change the AWS credentials file to the appropriate location of your AWS access keys, you must also change the location of your SSH PUBLIC key just below the AWS keys section.

To create the infrastructure run the following commands:
```
terraform init
terraform plan (it's always best to check what changes you're making before actually commiting to them)
terraform apply
```

Once the infrastructure has been successfully setup you will be met with a file containing a list of IP addresses for your newly created instances, this file is named `ips` access this file and edit the `hosts` file, the first IP in the `ips` list will be your manager, and every other remaining IP address below this will be your workers, place these in the correct sections of the `hosts` file.

Now once the hosts file has been created to the format specified above you're ready to configure your docker swarm cluster!

To do this run the following command:
```
ansible-playbook -i hosts -u ubuntu --private-key "~/.ssh/id_ed25519" docker-swarm.yml
```
Make sure to update the `--private-key` section with the correct location of your PRIVATE key.

Once this has hopefully completed successfully without any errors you're ready to deploy the Hugo Stack!

The next step will be to read through the `docker-compose.yml` file and changing every section that applies, MAKE SURE YOU CHECK THE `LABELS` SECTION FOR EACH SERVICE!

In this file there's multiple places which you will need to modify, search "example.com" to find the entries where you need to specify your own domain name, then you must also update the cloudflare API key and EMAIL in order for traefik to issue certificates properly.

You can update the domain accordingly using the following command,
```
sed -i 's/example.com/YOURDOMAIN.COM/g' docker-compose.yml
```

However you must still update the CLOUDFLARE API section in order to be able to properly issue SSL certificates, you may also use different methods of ACME validation, to do so first lookup information on how to do so with Traefik; it relies on <5 lines to modify this.

Run the following to deploy the hugo stack from the `docker-compose.yml` file,
```
ansible-playbook -i hosts -u ubuntu --private-key "~/.ssh/id_ed25519" docker-deploy.yml
```
Once again, check to make sure you have set the `--private-key` tag to the correct location of your private key file!

Once that has completed you should have a fully functional Hugo stack setup on your brand new docker swarm cluster!

Whilst this project could be improved, this is just a fun little experiment just to pass a bit of free time, however feel free to modify the code anyway you wish and actually use this in a future project of yours, good luck! :)