# Move instances and volumes between Availability Domains
## Overview

This repository contains terraform and shell which can create backups of existing
instances, boot volumes, and block volumes and re-deploy them in another availability domain. There are three scripts intended to be run within Cloud Shell in the OCI console. No local setup is needed.

**Note**: these scripts assume the following:
- Instances and volumes are in the same compartment.
- The subnet the instances are in is regional and a suitable target for new instances.
- Public IPs of instances are not retained, but private IPs and hostnames are.
- The instances and applications running on them have been stopped.

## Steps

- Open [Cloud Shell](https://cloud.oracle.com/?bdcstate=default&cloudshell=true) in your browser.

- Grab the content of this repo by running the below commands in the Cloud Shell prompt:
```
wget https://github.com/oracle-quickstart/oci-migrate-ad/archive/refs/heads/main.zip && \
unzip main.zip && \
cd oci-migrate-ad-main/
```

- Run `oci iam availability-domain list`. The output will have the tenancy specific
names of the ADs in your region.

- Edit `env.sh` setting the following variables:
  - `TF_VAR_compartment_ocid` the compartment containing your instances, this can be the root compartment.
  - `TF_VAR_availability_domain` the name of the AD the instances are in.
  - `TF_VAR_destination_availability_domain` the name of the AD to create new resources in.

- Stop applications running on the instances and then stop the instances in the console.

- Run `./backup.sh` which performs these actions:
  - Inspects existing instances and volumes.
  - Creates boot and block volume backups.
  - Creates new boot and block volumes in the destination AD.
  - **Note**: you will be prompted to continue.

- Optionally run `./terminate.sh` (you will be prompted to continue) or terminate instances in the console. Termination allows for ip and hostname reuse.

- Run `./move.sh` which performs these actions:
  - Reads state from the run of the backup script.
  - Creates instances from the boot volume backups created previously (you will be prompted to continue).
  - Attaches the new block volumes
  - **Note**: if you see a `409` error related to ip or hostname being in use that's because they haven't been released by the terminated instances. Wait a short time and rerun the script.

- SSH into the new instances and check things are running correctly. 
