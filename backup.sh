
echo -e "Reading existing instances and backing up...\n\n"

terraform init
terraform plan
terraform apply
