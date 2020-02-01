
function ensure_packer() {
  PACKER_VERSION="${PACKER_VERSION:-"1.5.1"}";
  export PACKER="/usr/local/bin/packer-$PACKER_VERSION";
  if [ -f "$filename" ]; then
    log_info "Using Packer version $PACKER_VERSION.";
  else
    log_info "Installing OPA version $PACKER_VERSION";
    curl -sSLo "/tmp/packer.zip" https://releases.hashicorp.com/packer/$PACKER_VERSION/packer_${PACKER_VERSION}_linux_amd64.zip;
    cd /tmp && unzip packer.zip;
    mv packer $PACKER
    rm -f packer.zip;
    chmod u+x "$PACKER";
  fi;
}

function run_aws_packer() {
	local function_name=run_packer packer_directory ami_name_prefix ami_description parent_ami_prefix vpc_name bastion_name ssh_bastion_username ssh_bastion_private_key_file;
	import_args "$@";
	check_required_arguments $function_name packer_directory ami_name_prefix ami_description vpc_name;
	check_required_variables security_group_name subnet_name aws_region;

	local ssh_bastion_host vpc_id;

	ensure_packer;
  get_vpc_id --vpc_name "$vpc_name" --target_variable_name vpc_id;
  get_instance_public_dns --instance_name "$bastion_name" --vpc_id "$vpc_id" --target_variable_name ssh_bastion_host;

	export packer_tmp_dir="/tmp/packer$$";
	export packer_target_dir="/tmp/packer$$";
  mkdir $packer_tmp_dir;
	cp -R $packer_directory/provisioner/* $packer_tmp_dir;

  run_or_source_files --directory "$packer_directory" --filename_pattern 'init*';

  local json_filename="$packer_directory/packer.json";
  [[ ! -f "$json_filename" ]] && log_error "File '$json_filename' must exist." && exit 1;

	if [ -z "$source_ami" ]; then
        if [ -z "$parent_ami_prefix" ]; then
            log_error "Variable 'parent_ami_prefix' is required if 'source_ami' is empty";
            exit 1;
        else
            log_info "Looking for AMI with name starting with '$parent_ami_prefix'";
            source_ami="$(get_ami --ami_name_prefix "$parent_ami_prefix")";
        fi;
        if [ -z "$source_ami" -o "$source_ami" == "-null-" -o "$source_ami" == "null" ]; then
            log_error "Unable to find an AMI with name starting with '$parent_ami_prefix'";
        fi;
    fi;

    log_info "Using source ami '$source_ami'";
    extra_packer_options="";
    if [ "$debug_mode" == "1" ]; then
        extra_packer_options="-debug";
        export PACKER_LOG=1;
    fi;

    [[ "$do_encrypt_boot" == "1" ]] && export encrypt_boot="true" || export encrypt_boot="false";

    log_info "Initializing Packer environment.";

    get_vpc_id --vpc_name "$vpc_name" --target_variable_name vpc_id;
    get_bastion_public_dns --vpc_id "$vpc_id" --bastion_name "$bastion_name" --target_variable_name ssh_bastion_host;
    get_security_group_id --vpc_id "$vpc_id" --security_group_name $security_group_name --target_variable_name security_group_id;
    get_subnet_id --vpc_id "$vpc_id" --subnet_name $subnet_name --target_variable_name subnet_id;

    export vpc_id subnet_id security_group_id ssh_bastion_host ssh_bastion_private_key_file source_ami;
    log_info "Using bastion $ssh_bastion_host and private key $ssh_bastion_private_key_file";
    if [ ! -f "$ssh_bastion_private_key_file" ]; then
        log_fatal "Bastion private key file doesn't exist: $ssh_bastion_private_key_file.";
    fi;
    log_info "Using vpc '$vpc_id', security group '$security_group_id', subnet '$subnet_id' and bastion '$ssh_bastion_host'.";
	oldpwd="$(pwd)";

	cd $packer_tmp_dir

	$packer build $extra_packer_options -machine-readable $json_filename | tee result.out

	grep 'artifact,0,id' result.out | cut -d, -f6 | cut -d: -f2
	ami_id="$(grep 'artifact,0,id' result.out | cut -d, -f6 | cut -d: -f2)";

	echo "--------- ami: --$ami_id-- --------";
	cd $oldpwd;
}

