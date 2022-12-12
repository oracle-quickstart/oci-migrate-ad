###
# TF, provider versions
###
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    # Recommendation from ORM / OCI provider teams
    oci = {
      version = ">= 4.21.0"
    }
  }
}

###
# Variables
###
variable "tenancy_ocid" {
}

variable "region" {
}

variable "availability_domain" {
  default = "IYfK:US-ASHBURN-AD-1"
}

variable "destination_availability_domain" {
  default = "IYfK:US-ASHBURN-AD-2"
}


variable "compartment_ocid" {
}

###
# Local to parse other state file
###

locals {
  state_file = jsondecode(file("${path.module}/../terraform.tfstate"))
  old_instances = { for instance in local.state_file.outputs.existing_instances.value :
  instance.id => instance }
  num_instances    = length(local.old_instances)
  new_boot_volumes = local.state_file.outputs.new_boot_volumes.value[0]
  new_volumes      = local.state_file.outputs.new_volumes.value[0]
  #new_volume_by_old_instance =
  old_vnics        = local.state_file.outputs.existing_vnics.value
  old_attachments  = local.state_file.outputs.existing_block_volume_attachments.value.volume_attachments
}

###
# New instances
###


resource "oci_core_instance" "new_instances" {
  for_each            = local.old_instances
  availability_domain = var.destination_availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = each.value.display_name
  shape               = each.value.shape
  dynamic "shape_config" {
    for_each = (each.value.shape_config != null ? [1] : [])
    content {
      ocpus         = each.value.shape_config[0].ocpus
      memory_in_gbs = each.value.shape_config[0].memory_in_gbs
    }
  }

  create_vnic_details {
    subnet_id              = local.old_vnics[each.key].subnet_id
    display_name           = local.old_vnics[each.key].display_name
    assign_public_ip       = (local.old_vnics[each.key].public_ip_address == "" ? false : true)
    nsg_ids                = local.old_vnics[each.key].nsg_ids
    #private_ip             = local.old_vnics[each.key].private_ip_address
    #hostname_label         = local.old_vnics[each.key].hostname_label
    skip_source_dest_check = false
  }

  source_details {
    source_id   = local.new_boot_volumes[each.key].id
    source_type = "bootVolume"
  }

  metadata = {
    "ssh_authorized_keys" = each.value.metadata.ssh_authorized_keys
  }
  freeform_tags = { "old_instance" = each.key }
}

###
# New attachments
###

resource "oci_core_volume_attachment" "test_volume_attachment" {
  for_each = {
    for attachment in local.old_attachments :
  attachment.id => attachment }

  attachment_type = each.value.attachment_type
  instance_id     = oci_core_instance.new_instances[each.value.instance_id].id
  volume_id       = local.new_volumes[each.key].id
  #depends_on = [oci_core_instance.new_instances]
}

###
# Outputs
###

#output "old_instances" {
#  value = local.old_instances
#}

output "new_instances" {
  value = oci_core_instance.new_instances
}
#output "state_file" {
#  value = local.state_file
#}
