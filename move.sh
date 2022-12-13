
echo -e "Creating new instances...\n\n"

cd instances
terraform init
terraform plan
terraform apply
