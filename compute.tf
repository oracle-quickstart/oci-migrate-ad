
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
# Data source to list all instances, boot, block
###

data "oci_core_instances" "existing_instances" {
  compartment_id = var.compartment_ocid
  filter {
    name   = "state"
    values = ["RUNNING", "STOPPED"]
  }
}

data "oci_core_boot_volumes" "existing_boot_volumes" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
}

data "oci_core_boot_volume_attachments" "existing_boot_volume_attachments" {
  for_each            = toset(data.oci_core_instances.existing_instances.instances[*].id)
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  instance_id         = each.key
}

data "oci_core_volumes" "existing_block_volumes" {
  #Optional
  #availability_domain = var.volume_availability_domain
  compartment_id = var.compartment_ocid
}

data "oci_core_volume_attachments" "existing_volume_attachments" {
  
  compartment_id = var.compartment_ocid

  #Optional
  availability_domain = var.availability_domain
  #instance_id = oci_core_instance.test_instance.id
  #volume_id = oci_core_volume.test_volume.id
}

data "oci_core_vnic_attachments" "test_vnic_attachments" {
  for_each       = toset(data.oci_core_instances.existing_instances.instances[*].id)
  compartment_id = var.compartment_ocid
  instance_id    = each.key
}

data "oci_core_vnic" "test_vnic" {
  for_each = data.oci_core_vnic_attachments.test_vnic_attachments
  vnic_id  = each.value.vnic_attachments[0].vnic_id
}

###
# Create backups and volumes
###

resource "oci_core_boot_volume_backup" "test_boot_volume_backup" {
  for_each = {
    for attachment in data.oci_core_boot_volume_attachments.existing_boot_volume_attachments :
  attachment.instance_id => attachment.boot_volume_attachments[0].boot_volume_id }
  boot_volume_id = each.value

  #Optional
  display_name  = "instance-${each.key}"
  freeform_tags = { "instance" = each.key }
  type          = "FULL"
}

resource "oci_core_boot_volume" "test_boot_volume" {
  for_each = oci_core_boot_volume_backup.test_boot_volume_backup

  compartment_id      = var.compartment_ocid
  availability_domain = var.destination_availability_domain
  display_name  = "volume-${each.key}"
  source_details {
    id   = oci_core_boot_volume_backup.test_boot_volume_backup[each.key].id
    type = "bootVolumeBackup"
  }
}


###
# Outputs
###

output "existing_instances" {
  value = data.oci_core_instances.existing_instances.instances[*]
}

output "existing_boot_volumes" {
  value = data.oci_core_boot_volumes.existing_boot_volumes
}

output "existing_boot_volume_attachments" {
  value = data.oci_core_boot_volume_attachments.existing_boot_volume_attachments
}

output "existing_block_volumes" {
  value = data.oci_core_volumes.existing_block_volumes
}

output "existing_block_volume_attachments" {
  value = data.oci_core_volume_attachments.existing_volume_attachments
}

output "existing_vnic_attachments" {
  value = data.oci_core_vnic_attachments.test_vnic_attachments
}

output "existing_vnics" {
  value = data.oci_core_vnic.test_vnic
}

output "new_boot_volumes" {
  value = oci_core_boot_volume.test_boot_volume[*]
}
