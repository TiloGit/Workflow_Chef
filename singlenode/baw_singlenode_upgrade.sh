#!/bin/bash
# set -e
# Any subsequent(*) commands which fail will cause the shell script to exit immediately
#
# Operating Systems Supported
# Ubuntu 16.04 LTS; Ubuntu 18.04 LTS
#
# This script deploys IBM Business Automation Workflow Enterprise V18 on a Linux virtual machine.

# Topology
# SNode: 1 virtual machine, IBM Business Automation Workflow Enterprise V18 - Deployment Manager and Custom Node, one cluster member.


# Generate temporary dir (do not delete it by this program)
Create_Log_Dir () {

  local i=0 # The times which attempt to create temporary dir 
  local logdir=

  while ((++i <= 10)); do
  logdir=${LOG_DIR:="/var/log/baw_singlenode_chef/"}
  mkdir -m 755 -p "$LOG_DIR" 2>/dev/null && break
  done

  if ((i > 10)); then
  printf 'Could not create Log directory\n' >&2
  exit 1
  fi

  # echo "Log directory $logdir created"
}


Print_TopologyLogs () {

  echo
  echo "Logs for details are under $LOG_DIR directory"
  echo
  echo "The monitor"
  echo "  Log to $BAW_CHEF_LOG"
  echo
  echo "Topology"
  echo
  echo "  SNode: 1 virtual machine, IBM Business Automation Workflow Enterprise V18 - Deployment Manager and Custom Node, one cluster member."
  echo "  Log to $SNODE_LOG"
  echo
}


# Upload all roles to the chef server
Upload_Roles () {

    knife role from file $BAW_CHEF_TEMP_DIR/$SNODE_ROLE_UPGRADE_FILE || return 1
    knife role from file $BAW_CHEF_TEMP_DIR/$SNODE_ROLE_APPLYIFIX_FILE || return 1
    knife role from file $BAW_CHEF_TEMP_DIR/$SNODE_ROLE_CONFIG_FILE || return 1
    knife role from file $BAW_CHEF_TEMP_DIR/$SNODE_ROLE_POSTDEV_FILE
}


######## BAW Installation ########
BAW_Single_Node_Installation_Start () {
  # sequential

    echo
    echo "$(date -Iseconds), MTASK: $LOG_SNODE_NAME TASKS List (Upgrade, Applyifix, Configuration, POST) starts"

    knife node run_list set $SNODE_ON_CHEF_SERVER "role[$SNODE_ROLE_UPGRADE_NAME]" || return 1
    echo "doing, please wait"
    echo
    knife ssh "name:$SNODE_ON_CHEF_SERVER" -a ipaddress "sudo chef-client" -x $SNODE_ROOT_USERNAME -P $SNODE_ROOT_PW >> $SNODE_LOG || return 1

    knife node run_list add $SNODE_ON_CHEF_SERVER "role[$SNODE_ROLE_APPLYIFIX_NAME]" || return 1
    echo "doing, please wait"
    echo
    knife ssh "name:$SNODE_ON_CHEF_SERVER" -a ipaddress "sudo chef-client" -x $SNODE_ROOT_USERNAME -P $SNODE_ROOT_PW >> $SNODE_LOG || return 1

    knife node run_list add $SNODE_ON_CHEF_SERVER "role[$SNODE_ROLE_CONFIG_NAME]" || return 1
    echo "doing, please wait"
    echo
    knife ssh "name:$SNODE_ON_CHEF_SERVER" -a ipaddress "sudo chef-client" -x $SNODE_ROOT_USERNAME -P $SNODE_ROOT_PW >> $SNODE_LOG || return 1

    knife node run_list add $SNODE_ON_CHEF_SERVER "role[$SNODE_ROLE_POSTDEV_NAME]" || return 1
    echo "doing, please wait"
    echo
    knife ssh "name:$SNODE_ON_CHEF_SERVER" -a ipaddress "sudo chef-client" -x $SNODE_ROOT_USERNAME -P $SNODE_ROOT_PW >> $SNODE_LOG || return 1
    echo "$(date -Iseconds), STATUS: $LOG_SNODE_NAME TASKS List (Installation, Upgrade, Applyifix, Configuration) was done successfully"
    echo
}


######## Programs below ########

######## Include libs ########
MY_DIR=${0%/*}
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; readonly MY_DIR; fi
#echo current Dir is $MY_DIR


######## Start the program ########
BAW_Single_Nodes_Chef_Start () {

  Upload_Roles || return 1
  BAW_Single_Node_Installation_Start
}

Main_Start () {

  echo
  echo "Start to upgrade and configure IBM Business Automation Workflow Enterprise V18 on one node."
  echo
  echo "Starting at: $(date -Iseconds)"
  echo
  
  . "$MY_DIR/../libs/dynamic_roles_singlenode_script" &&

  ######## Prepare logs for nodes #######
  # The name for SNode in log printing
  # $SNODE_IP_ADDR depend on . "$MY_DIR/../libs/dynamic_roles_singlenode_script"
  LOG_SNODE_NAME="SNode Workflow ($SNODE_IP_ADDR)"  
  readonly LOG_SNODE_NAME
  SNODE_LOG="${LOG_DIR}SNODE_${SNODE_IP_ADDR}_chef.log"
  readonly SNODE_LOG

  Print_TopologyLogs

  BAW_Single_Nodes_Chef_Start 
  local task_main_exit_status=$?

  echo
  echo "Done at: $(date -Iseconds)"
  echo

  if [ $task_main_exit_status -eq 0 ]
  then
      echo
      echo "All Tasks Complete successfully."
      echo
  else
      echo
      echo "Failed, There may be errors occurred."
      echo
  fi

  Print_TopologyLogs
  echo
  echo
}

######## Prepare logs #######
# define where to log
LOG_DIR="/var/log/baw_singlenode_chef/"
BAW_CHEF_LOG="${LOG_DIR}BAW_CHEF_SCRIPT_chef.log"
readonly BAW_CHEF_LOG
Create_Log_Dir

 Main_Start 2>&1 | tee $BAW_CHEF_LOG