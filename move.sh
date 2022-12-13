
echo "Creating new instances..."

cd instances
terraform init
terraform plan
terraform apply
