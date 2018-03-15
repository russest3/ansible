#!/bin/bash

source $JENKINS_HOME/jobs/$PROMOTED_JOB_NAME/builds/$PROMOTED_NUMBER/archive/maven_info.txt

cd `dirname $0`

projectTypes=(`ls -1 *.yml | grep -v variables_global.yml | sed -e 's/.yml$//'`)
allEnvironments=(`ls -1 roles/*/environments/* | sed -e 's,^.*\/,,' | sort | uniq`)

array_contains () {
    local seeking=$1; shift
    local in=1
    for element; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}

join() {
	local IFS=$1
	shift
	echo "$*"
}

function usage() {
	echo "Usage: $0 <environment> <project_type> <group_id> <artifact_id> <project_version> <steps>"
	echo "Parameters:"
	echo -n "* Environment = can be one of: "
	join ", " "${allEnvironments[@]}" 
	echo -n "* Project Type = can be one of: "
	join ", " "${projectTypes[@]}"
	echo "* Group ID = component group under which it's listed in Nexus"
	echo "* Artifact ID = component name under which it's listed in Nexus"
	echo "* Project Version = component version which is in Nexus"
	echo "* Steps = what steps to run: initialize, configure, deploy"
	echo
	echo "Required environment variables:"
	echo "ANSIBLE_LIBRARY - location of Ansible Modules Extras"
}

if [[ "$#" -ne 6 ]]; then
	usage
	exit 1
fi

if [[ -z "$ANSIBLE_LIBRARY" ]]; then
	echo "Missing ANSIBLE_LIBRARY environment variable"
	echo
	usage
	exit 1
fi

if ! array_contains $2 "${projectTypes[@]}" ; then
	echo "ERROR $2 is not valid projec type"
	echo
	usage
	exit 2
fi

projectEnvironments=(`ls -1 roles/$2/environments/* | sed -e 's,^.*\/,,' | sort | uniq`)
if  ! array_contains $1 "${projectEnvironments[@]}" ; then
	echo -n "ERROR '$1' is not valid environment for project type '$2'. Available environments for this project type are: "
	join ", " "${projectEnvironments[@]}"
	echo
	usage
	exit 3
fi

# Use default login options for running from developers local machine
# Automatic deployment scripts should export this variable when calling this script pass proper SSH key
#if [[ -z "$ANSIBLE_LOGIN_OPTS" ]]; then
#	ANSIBLE_LOGIN_OPTS="-k -u `id -un` -s -K"
ANSIBLE_LOGIN_OPTS="-k -u jenkins -K"
#fi

ANSBLE_VAULT_FILE=""
if [[ -f $HOME/.ansible_vault_pass.txt ]]; then
	ANSBLE_VAULT_FILE="--vault-password-file $HOME/.ansible_vault_pass.txt"
fi

# Set Maven Repository URL
if [ $(( ${#5})) -gt 5 ]; then
	maven_repository_url="http://10.0.1.20:8081/artifactory/snapshots/"
else
	maven_repository_url="http://10.0.1.20:8081/artifactory/releases/"
fi

set -x
ansible-playbook -vvv --forks=1 $ANSIBLE_LOGIN_OPTS $ANSBLE_VAULT_FILE --inventory=$ANSIBLE_REPO/roles/$2/environments/$1 --extra-vars="maven_repository_url=$maven_repository_url env=$1 project_group_id=$3 project_artifact_id=$4 project_version=$5" --tags=$6 ${2}.yml --limit=$4
