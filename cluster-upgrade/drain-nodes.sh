#!/bin/bash

GET_NODES="kubectl get nodes"
COUNT_PODS="kubectl get pods --all-namespaces -o wide"
POD_COUNT=2
INFO_ONLY=false
NO_COLOR=false

function output_help {
    echo "Drain out the node pool based on the name provided";
    echo "";
    echo "Example: `basename $0` --name master-6bfaec ";
    echo "";
    echo "Options:";
    echo "  -n  --name     the name of the node pool that will be drained ";
    echo "                    (preferably with the unique id to distinguish it";
    echo "                     from the new node pool)";
    echo "  -c  --count    count of non-running pods (completed/error) in the cluster before starting draining process (default 2)";
    echo "      --dry-run  only output the current resource usage of the nodes";
    echo "      --no-color remove the additional color from the output";
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--name)
    NAME="$2"
    shift
    shift
    ;;
    -c|--count)
    POD_COUNT="$2"
    shift
    shift
    ;;
    --dry-run)
    INFO_ONLY=true
    shift
    ;;
    --no-color)
    NO_COLOR=true
    shift
    ;;
    -h|--help)
    output_help
    exit 0
    shift
    ;;
    *)    # unknown option
    echo "Option: $key is unknown"
    output_help
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# check that there is a name to filter by
if [ ! -n "$NAME" ] ; then
    echo "Node pool name is not set. Try using '--help' for help in using script."
    exit 0
fi

# ----------------
#  ECHO COLORING
# ----------------

# $1 content to echo
# $2 color
function c_echo {
    if [ "$NO_COLOR" = true ] ; then
        echo $1
    fi
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
    case $2 in
        red)
            printf "${RED}%b${NC}\n" "${1}"
        ;;
        green)
            printf "${GREEN}%b${NC}\n" "${1}"
        ;;
        yellow)
            printf "${YELLOW}%b${NC}\n" "${1}"
        ;;
        cyan)
            printf "${CYAN}%b${NC}\n" "${1}"
        ;;
        *)
            printf "%b\n" "${1}"
    esac
}

# ----------------
#  HELPER FUNCTIONS
# ----------------

function are_pods_not_running() {
    local counter
    counter=0
    while read -r w1 w2 w3 w4 w5 ; do
        if [ $w4 != "Running" ] && [ $w4 != "STATUS" ]; then
            let counter=counter+1
        fi
    done <<< "$($COUNT_PODS)"
    if [ "$counter" -gt "$1" ] ; then
        true
    else
        false
    fi
}

# $1 nodeName
# $2 additional flag
function drain_node() {
    local output
    c_echo ""
    c_echo " $ kubectl drain --ignore-daemonsets --force $2 $1"
    # TODO: an area for improvment is to have a synchronous output to the user
    output=$((kubectl drain --ignore-daemonsets --force $2 $1) 2>&1)
    if [[ "$output" =~ "Unknown controller kind" ]] ; then
        c_echo "$output"
        echo ""
        c_echo "The pod without a controller needs to be deleted manually." "yellow"
        echo -n "Once the pod is deleted, continue this script again clicking [ENTER] or ('s' to skip this node): "
        read skip
        if [ "$skip" != "s" ] ; then
            drain_node $1 "$2"
        fi
    elif [[ "$output" =~ "unable to drain node" ]] ; then
        c_echo "$output" "yellow"
        echo ""
        echo -n "Re-run 'drain' with additional flags (use 'c' to continue without re-running): "
        read flag
        if [ "$flag" != "c" ] ; then
            drain_node $1 "$flag"
        fi
    else
        c_echo "$output" "green"
    fi
}

function wait_for_pods_to_migrate() {
    c_echo "Waiting for all (no less than $POD_COUNT) pods to start running again"
    while are_pods_not_running $POD_COUNT ; do
        printf "."
        sleep 5
    done
    c_echo "   done waiting"
}

# $1 nodeName
function echo_resource_usage() {
    c_echo "  resource usage for: $1  " "cyan"
    c_echo "  ------------------------"
    c_echo "$(kubectl describe node $1 | grep Allocated -A 5 |
            grep -ve Event -ve Allocated -ve percent -ve --)"
    c_echo ""
}

# ----------------
# GET INFO ABOUT NODES
# ----------------

if are_pods_not_running $POD_COUNT ; then
    c_echo "Not enough pods are running. Adjust with -c option, and/or" "red"
    c_echo "  check which pods are running/not:" "red"
    c_echo "    $COUNT_PODS | grep -ve Running"
    exit 2
fi

#  create an array of the names, so they don't change while script is running
NODES=()
c_echo "These are the nodes that will be drained:"
while read -r n_name n_status n_role n_age n_version ; do
    c_echo "  $n_name"
    NODES+=($n_name)
done <<< "$($GET_NODES | grep $NAME)"

if [ ${#NODES[@]} -eq 0 ]; then
    c_echo "No nodes found when filtering by: $NAME" "red"
    c_echo ""
    exit 0
fi

# get resource info for each node
c_echo ""
for n in "${NODES[@]}" ; do
    echo_resource_usage $n
done
if [ "$INFO_ONLY" = true ] ; then
    exit 0
fi

c_echo ""
echo -n "Continue... [ENTER]"
read contunue


# ----------------
# DRAIN NODES
# ----------------

# disabled - to avoid problems with GCP LB
# mark each Node as unschedulable
# for n in "${NODES[@]}" ; do
#     c_echo "$(kubectl cordon $n)"
# done

for n in "${NODES[@]}" ; do
    c_echo "Draining $n..." "cyan"
    drain_node $n ""
    wait_for_pods_to_migrate
    c_echo ""
    echo -n "Are you ready for the next node... [ENTER]"
    read ready
    c_echo ""
done
c_echo "No more nodes to check!" "green"

# ----------------
# DISPLAY RESOURCE USAGE AFTER
# ----------------

c_echo ""
for n in "${NODES[@]}" ; do
    echo_resource_usage $n
done

# for more info about node resources usage, try:
#   kubectl describe node <NODE NAME> | grep Non-terminated -A 10 | grep -ve percent -ve Event -ve --
