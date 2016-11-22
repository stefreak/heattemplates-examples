#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

cd $(dirname $0)

if [[ $# -ne 2 ]]
  then
    echo "usage: ${0} stack_name_1 stack_name_2"
    exit
fi

get_output() {
	stackName=$1
	varName=$2

	openstack stack output show "${stackName}" "${varName}" -fvalue  -coutput_value
}

create_environment_activating() {
  activeStackName=$1
  inactiveStackName=$2

  production_port_id=`get_output "${activeStackName}" "production_port_id"`
  staging_port_id=`get_output "${inactiveStackName}" "staging_port_id"`

  cat <<EOF> ipassociation-env-activate-${activeStackName}.yaml
parameters:
  production_port_id: ${production_port_id} 
  staging_port_id:  ${staging_port_id} 

  production_stack_name: ${activeStackName}
  staging_stack_name: ${inactiveStackName}
EOF
}

greenStack=$1
blueStack=$2

create_environment_activating $blueStack $greenStack
create_environment_activating $greenStack $blueStack

echo "created two files:"
echo "    - ipassociation-env-activate-${greenStack}.yaml"
echo "    - ipassociation-env-activate-${blueStack}.yaml"
echo ""
echo "to get started run"
echo "    $ openstack stack create -t ipassociation.yaml -e ipassociation-env-activate-${greenStack}.yaml <ipassociation stack name>"
echo ""
echo "to flip staging and production stacks later just run"
echo "    $ openstack stack update -t ipassociation.yaml -e ipassociation-env-activate-${blueStack}.yaml <ipassociation stack name>"
echo ""
echo "to get the current production / staging stacks just run"
echo "    $ openstack stack output show <ipassociation stack name> --all"
