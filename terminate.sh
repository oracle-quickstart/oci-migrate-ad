

instances=$(cat terraform.tfstate | jq -r '.outputs.existing_instances.value')

instance_ids=$(echo $instances | jq -r '.[].id')
instance_names=$(echo $instances | jq -r '.[] | "\(.display_name) \(.id)"')

echo "Found instances:"
echo "$instance_names"
echo "\n"

for i in $instance_ids
do
  echo "Terminating instance $i"
  oci compute instance terminate --instance-id $i --preserve-boot-volume true
done
