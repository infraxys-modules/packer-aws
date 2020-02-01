#!/usr/bin/env bash

set -eo pipefail;

vpc_name="$instance.getAttribute("vpc_name")";
#if ($instance.getAttribute("source_ami") == "")
parent_ami_prefix="$instance.parent.getAttribute("ami_name_prefix")";
#else
parent_ami_prefix="";
#end
#[[

run_aws_packer --packer_directory "$default_module_dir/packer" --vpc_name "$vpc_name" \
    --ami_name_prefix "$ami_name_prefix" \
    --ami_description "$ami_description" \
    --parent_ami_prefix "$parent_ami_prefix" \
    --bastion_name "$bastion_name" \
    --ssh_bastion_username "$ssh_bastion_username" \
    --ssh_bastion_private_key_file "$ssh_bastion_private_key_file";

]]#
