
###
# TF, provider versions
###
terraform {
  required_version = ">= 1.0.0"
  required_providers {
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
# Data sources to list all instances, boot, block
###

data "oci_core_instances" "existing_instances" {
  compartment_id = var.compartment_ocid
  availability_domain = var.availability_domain
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
  #for_each       = toset(data.oci_core_instances.existing_instances.instances[*].id)
  compartment_id = var.compartment_ocid
  #Optional
  availability_domain = var.availability_domain
  #instance_id         = each.key
  filter {
    name = "state"
    values = ["ATTACHED"]
  }
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

# Boot volumes

resource "oci_core_boot_volume_backup" "test_boot_volume_backup" {
  for_each = {
    for attachment in data.oci_core_boot_volume_attachments.existing_boot_volume_attachments :
  attachment.instance_id => attachment.boot_volume_attachments[0].boot_volume_id }
  boot_volume_id = each.value

  #Optional
  display_name  = {for instance in data.oci_core_instances.existing_instances.instances:  instance.id => instance}[each.key].display_name
  freeform_tags = { "instance" = each.key }
  type          = "FULL"
}

resource "oci_core_boot_volume" "test_boot_volume" {
  for_each = oci_core_boot_volume_backup.test_boot_volume_backup

  compartment_id      = var.compartment_ocid
  availability_domain = var.destination_availability_domain
  display_name        = {for instance in data.oci_core_instances.existing_instances.instances:  instance.id => instance}[each.key].display_name
  source_details {
    id   = oci_core_boot_volume_backup.test_boot_volume_backup[each.key].id
    type = "bootVolumeBackup"
  }
}

# Block volumes

resource "oci_core_volume_backup" "test_volume_backup" {

  for_each = {
    for attachment in data.oci_core_volume_attachments.existing_volume_attachments.volume_attachments :
  attachment.id => [attachment.instance_id, attachment.volume_id] }

  volume_id     = each.value[1]
  display_name  = {for volume in data.oci_core_volumes.existing_block_volumes.volumes:  volume.id => volume}[each.value[1]].display_name
  freeform_tags = { "instance" = each.value[0] }
  type          = "FULL"
}

resource "oci_core_volume" "test_volume" {
    for_each = oci_core_volume_backup.test_volume_backup

    compartment_id = var.compartment_ocid
    availability_domain = var.destination_availability_domain
    display_name = each.value.display_name
    source_details {
        #Required
        id = each.value.id
        type = "volumeBackup"
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

output "new_volume_backups" {
  value = oci_core_volume_backup.test_volume_backup[*]
}

output "new_volumes" {
  value = oci_core_volume.test_volume[*]
}
