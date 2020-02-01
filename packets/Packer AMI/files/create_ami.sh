#[[
#configure_aws_credentials;
log_info "Creating directory /tmp/packer/infraxys/$targetDirectory";
mkdir -p "/tmp/packer/infraxys/$targetDirectory";

eval "$pre_run_script";
]]#

#if ($instance.getAttribute("source_ami") == "")
source_ami="$(get_ami --ami_name_prefix $instance.parent.getAttribute("ami_name_prefix"))";
#[[
if [ -z "$source_ami" -o "$source_ami" == "-null-" -o "$source_ami" == "null" ]; then
    log_error "Unable to determine AMI. Aborting";
    exit 1;
fi;
log_info "Using source ami '$source_ami'";
]]#
#end

#foreach ($childInstance in $instance.getChildren())
    #if ($childInstance.getPacketType().equals("GITHUB_REPOSITORY"))
        #set ($githubInstanceVelocityName = $childInstance.getAttribute("github_account_velocity_name"))
        #set ($githubInstance = $velocityContext.get($githubInstanceVelocityName))
        #if (!$githubInstance)
            $environment.throwException("No instance with Velocity name '$githubInstanceVelocityName' found in this environment")
        #end

#set ($repository = $childInstance.getAttribute("github_repository"))
#set ($targetDirectory = $childInstance.getAttribute("github_target_directory"))
#set ($organization = $githubInstance.getAttribute("github_username_or_org"))

log_info "Directory created";
git_clone_repository --github_domain "$githubInstance.getAttribute("github_domain")" \
        --github_token "$githubInstance.getAttribute("github_token")" \
        --organization "$organization" \
        --repository "$repository" \
        --branch "$childInstance.getAttribute("github_branch")" \
        --target_directory "/tmp/packer/infraxys/$targetDirectory";
    #elseif ($childInstance.getPacketType().equals("AUTH0-CONFIG"))
        cp ../../../$childInstance.getRelativePath()/auth0.properties /tmp/packer/auth0.properties;
    #end
#end

#[[
extra_packer_options="";
if [ "$debug_mode" == "1" ]; then
    extra_packer_options="-debug";
    export PACKER_LOG=1;
fi;

[[ "$do_encrypt_boot" == "1" ]] && export encrypt_boot="true" || export encrypt_boot="false";
set_default_ssh_options;
start_module --git_url "$packer_module_git_url" --git_branch "$packer_module_git_branch";
]]#