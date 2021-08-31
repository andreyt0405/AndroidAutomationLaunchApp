#!/bin/bash
DEFAULT_MAX_ROUNDS_PER_INSTALL=300
DEFAULT_LAUNCH_TIMEOUT=15
ADB_CLEAR_LOG_TIMEOUT=3
LOG_DIR=''

DEVICE_ID_LIST=()
DEVICE_MODEL_LIST=()
SHOULD_PRINT_DEBUG_LOG=0

declare -a ERROR_PATTERNS=(
    "ActivityManager.*ANR in "${PACKAGE} 
    "beginning of crash"
    "Appdome Fatal"
    "Build fingerprint: "
    "SIGFPE"
    "FATAL EXCEPTION: UnityMain"
    )
declare -a EVENT_PATTERNS=(
    "send_dev_event_with_map"
    )

RED=`tput setaf 1`
GREEN==`tput setaf 2`
YELLOW=`tput setaf 3`
CYAN=`tput setaf 6`
NO_COLOR=`tput sgr0`

print_message() {
    echo "[+]" $* >&2
}

print_error() {
    echo "${RED}[X]- ${FUNCNAME[1]} -" $* ${NO_COLOR} >&2
}

print_debug() {
    if [ $SHOULD_PRINT_DEBUG_LOG -gt "0" ]; then
        echo "[DEBUG] - ${FUNCNAME[1]} -" $* >&2
    fi
}

print_fail() {
    echo "${YELLOW}[x] FAIL - "$* >&2 ${NO_COLOR}
}

print_section() {
    echo "${CYAN}[*]" $* >&2 ${NO_COLOR}
}

is_adb_device_connected() {
    if [[ $(adb devices | grep -v "List of devices attached") ]]; then
        return 0;
    else
        return 1;
    fi
}

package_exists_on_device() {
    device_id=$1
    package=$2
    if [ -z $device_id ]; then
        print_error "${FUNCNAME[0]} - Device ID is empty"
        exit
    fi

    if [[ $(adb -s $device_id shell pm list packages | grep -i "^package:"$package"$") ]]; then
        return 0;
    else
        return 1;
    fi
}

print_connected_devices() {
    echo "======================="
    print_message "Devices:"

    for (( i=0; i<${#DEVICE_ID_LIST[@]}; i++ ));
    do
        device_id=${DEVICE_ID_LIST[$i]}
        device_name="${DEVICE_MODEL_LIST[$i]}"
        echo "[$i] Device: "$device_name" with ID: "$device_id
    done
    echo "======================="
    echo ""
}

get_connected_device_details() {
    DEVICE_ID_LIST=(`adb devices | grep -v "List of devices attached" | awk 'NF' | awk {'print $1'}`)
    for (( i=0; i<${#DEVICE_ID_LIST[@]}; i++ ));
    do
        device_id=${DEVICE_ID_LIST[$i]}
        device_name="`adb -s $device_id shell getprop ro.product.device | tr -d \" \"`"_"`adb -s $device_id shell getprop ro.product.model | tr -d \" \"`"
        DEVICE_MODEL_LIST+=($device_name)
    done

    if [ ${#DEVICE_MODEL_LIST[@]} -gt ${#DEVICE_ID_LIST[@]} ]; then
        print_error "Device ID and Model list aren't equal in size"
        exit
    fi
    print_connected_devices
}

check_connected_devices() {
    if ! is_adb_device_connected ; then
        print_error "No connected devices found. Please connect a device to continue"
        exit
    fi
    get_connected_device_details
}

verify_device_id() {
    device_id=$1
    if [ -z $device_id ]; then
        print_error "${FUNCNAME[1]} - Device ID is empty"
        exit
    fi
}

verify_device_name() {
    device_name=$1
    if [ -z $device_name ]; then
        print_error "${FUNCNAME[1]} - Device Name is empty"
        exit
    fi
}

log_root() {
    root_dir=$LOG_DIR
    if [ ! -e "$root_dir" ]; then
        mkdir $root_dir
    fi

    today=`date '+%m_%d'`;
    if [ ! -e "$root_dir/$today" ]; then
        mkdir $root_dir/$today
    fi

    log_today_root="$root_dir/$today"
    echo $log_today_root
}

log_current() {
    device_name=$1
    verify_device_name $device_name
    log_current=$(log_root)"/current_"$device_name
    echo $log_current
}

test_log_root() {
    device_name=$1
    verify_device_name $device_name
    test_log_current=$(log_root)"/$device_name/testlogs"
    if [ ! -e "$test_log_current" ]; then
        mkdir -p "$test_log_current"
    fi
    echo $test_log_current
}

crash_log_root() {
    device_name=$1
    verify_device_name $device_name
    crash_log_root=$(log_root)"/$device_name/crashlogs"
    if [ ! -e "$crash_log_root" ]; then
        mkdir -p  "$crash_log_root"
    fi
    echo $crash_log_root
}

event_log_root() {
    device_name=$1
    verify_device_name $device_name
    event_log_root=$(log_root)"/$device_name/eventlogs"
    if [ ! -e "$event_log_root" ]; then
        mkdir -p  "$event_log_root"
    fi
    echo $event_log_root
}

copy_log() {
    device_name=$1
    verify_device_name $device_name

    log=$(log_current $device_name)
    root_dir=$(test_log_root $device_name)
    if [ ! -e "$root_dir" ]; then
        mkdir $root_dir
    fi
    today=`date '+%Y_%m_%d__%H_%M_%S'`;
    filename_prefix="$root_dir/$PACKAGE"
    filename="${filename_prefix%.*}_I${INSTALL_ROUND_COUNTER%.*}R${PER_INTSALL_COUNTER%.*}_test_$today.log"

    touch $filename
    print_message "Copying test logs to: "$filename
    cp $log $filename
}

copy_crash() {
    device_name=$1
    verify_device_name $device_name

    crash_log=$(log_current $device_name)
    root_dir=$(crash_log_root $device_name) 
    if [ ! -e "$root_dir" ]; then
        mkdir $root_dir
    fi
    today=`date '+%Y_%m_%d__%H_%M_%S'`;
    filename_prefix="$root_dir/$PACKAGE"
    filename="${filename_prefix%.*}_I${INSTALL_ROUND_COUNTER%.*}R${PER_INTSALL_COUNTER%.*}_crash_$today.log"

    touch $filename
    print_message "Copying crash to logs to: $filename"
    cp $crash_log $filename
}

copy_event() {
    device_name=$1
    verify_device_name $device_name

    event_log=$(log_current $device_name)
    root_dir=$(event_log_root $device_name) 
    if [ ! -e "$root_dir" ]; then
        mkdir $root_dir
    fi
    today=`date '+%Y_%m_%d__%H_%M_%S'`;
    filename_prefix="$root_dir/$PACKAGE"
    filename="${filename_prefix%.*}_I${INSTALL_ROUND_COUNTER%.*}R${PER_INTSALL_COUNTER%.*}_event_$today.log"

    touch $filename
    print_message "Copying event to logs to: $filename"
    cp $event_log $filename
}

start_log() {
    device_id=$1
    device_name=$2
    verify_device_id $device_id 
    verify_device_name $device_name

    print_message "Restarting log for device "$device_name
    if [ -e "$(log_current $device_name)" ]; then
        rm $(log_current $device_name)
    fi
    adb -s $device_id shell -t "logcat -b all -c"
    sleep ${ADB_CLEAR_LOG_TIMEOUT}
    
    adb -s $device_id shell -T -tt "logcat" > $(log_current $device_name) &
}

print_install_index() {
    install_index=${INSTALL_ROUND_COUNTER}
    print_section "Install #$install_index"
}

print_run_index() {
    run_index=${PER_INTSALL_COUNTER}
    print_section "Run #$run_index"
}

start_app_on_device() {
    device_id=$1
    device_name=$2
    package=$3
    verify_device_id $device_id 
    verify_device_name $device_name

    print_message "Starting app on device "$device_name
    adb -s $device_id shell monkey -p $package -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1

    # Allow the application to launch
    print_message "Sleeping for " $LAUNCH_TIMEOUT
    sleep $LAUNCH_TIMEOUT &
}

kill_app_on_device() {
    device_id=$1
    device_name=$2
    package=$3
    verify_device_id $device_id 
    verify_device_name $device_name
    
    print_message "Stopping app on device "$device_name
    adb -s $device_id shell am force-stop $package
}

parse_logs() {
    device_id=$1
    device_name=$2
    verify_device_id $device_id 
    verify_device_name $device_name
    
    print_message "Looking for errors in log of device "$device_name
    
    for pattern in "${ERROR_PATTERNS[@]}"; do
        # print_message "looking for pattern: $pattern"
        if grep -q "$pattern" $(log_current $device_name)
        then
            print_fail "Found crash pattern: $pattern"
            copy_crash $device_name
            break
        fi
    done

    print_message "Looking for events in log of device "$device_name
    for pattern in "${EVENT_PATTERNS[@]}"; do
        # print_message "looking for pattern: $pattern"
        if grep -q "$pattern" $(log_current $device_name)
        then
            print_fail "Found event Pattern: $pattern"
            copy_event $device_name
            break
        fi
    done
}

clear_apk_cache() {
    device_id=$1
    device_name=$2
    package=$3
    verify_device_id $device_id 
    verify_device_name $device_name
    
    print_message "Clearing app cache for package on device "$device_name
    adb -s $device_id shell pm clear $package
}

print_usage() {
    echo "Usage:"
    echo "./android_loop_until_crash.sh <BUNDLEID_OF_TARGET> <OUTPUT_DIR> <NUMBER OF LAUNCHES> <LAUNCH TIMEOUT>"
    echo "Output dir - Default: The script will try use ANDROID_LOGS enviroment variable as the output folder"
    echo "Number of launches - Default: $DEFAULT_MAX_ROUNDS_PER_INSTALL"
    echo "Launch timeout - Default: $DEFAULT_LAUNCH_TIMEOUT"
}


wait_for_target_app_launch() {

    RUNNING_SLEEP_PIDS=(`jobs -l | grep "sleep" | awk {'print $2'}`)
    RUNNING_SLEEP_COUNT=${#RUNNING_SLEEP_PIDS[@]}
    print_message "Waiting for "$RUNNING_SLEEP_COUNT" target apps to finish launching"
    
    for (( i=0; i<${#RUNNING_SLEEP_PIDS[@]}; i++ ));
    do
        job=${RUNNING_SLEEP_PIDS[$i]}
        wait $job
    done
    print_message "All target apps launches have completed"
}

kill_all_logs() {
    RUNNING_ADB_PIDS=(`jobs -l | grep "adb -s" | awk {'print $2'}`)
    RUNNING_ADB_COUNT=${#RUNNING_ADB_PIDS[@]}
    print_message "Stopping "$RUNNING_ADB_COUNT" running adb logcats"
    
    for (( i=0; i<${#RUNNING_ADB_PIDS[@]}; i++ ));
    do
        job=${RUNNING_ADB_PIDS[$i]}
        kill $job 2>&1 > /dev/null
    done
    print_message "All adb logcats were stopped"
}

set_root_log_dir() {
    if [ -z "$OUTPUT_DIR" ] && [ -z $ANDROID_LOGS ]; then
        print_error "Output directory wasn't provided and enviroment variable ANDROID_LOGS wasn't set"
        print_usage
        exit
    fi

    if [ ! -z "$OUTPUT_DIR" ]; then
        LOG_DIR=$OUTPUT_DIR
    elif [ ! -z $ANDROID_LOGS ]; then
        print_debug "Using enviroment variable ANDROID_LOGS as output directory"
        LOG_DIR=$ANDROID_LOGS
    fi
}

parse_params() {
    
    if [ -z "$PACKAGE" ]; then
        print_error "Provide package name to test"
        print_usage
        exit
    fi 

    if [ -z "$MAX_ROUNDS_PER_INSTALL" ]; then
        print_debug "Using default number of launches"
        MAX_ROUNDS_PER_INSTALL=$DEFAULT_MAX_ROUNDS_PER_INSTALL 
    fi 

    if [ -z "$LAUNCH_TIMEOUT" ]; then
        print_debug "Using default launch time"
        LAUNCH_TIMEOUT=$DEFAULT_LAUNCH_TIMEOUT 
    fi     

    set_root_log_dir       
    print_parameters
}

print_parameters() {
    echo "======================="
    print_message "Parameters:"
    print_message "Target Package: " $PACKAGE
    print_message "Output directory: " $(log_root)
    print_message "Number of launces: " $MAX_ROUNDS_PER_INSTALL
    print_message "Launch timeout: " $LAUNCH_TIMEOUT
    echo "======================="
    echo ""
}

PACKAGE=$1
OUTPUT_DIR=$2
MAX_ROUNDS_PER_INSTALL=$3
LAUNCH_TIMEOUT=$4

parse_params
check_connected_devices

INSTALL_ROUND_COUNTER=1
PER_INTSALL_COUNTER=1

while true
do
    while true
    do
        print_run_index $PER_INTSALL_COUNTER
        for (( i=0; i<${#DEVICE_ID_LIST[@]}; i++ ));
        do
            device_id=${DEVICE_ID_LIST[$i]}
            device_name="${DEVICE_MODEL_LIST[$i]}"

            if ! package_exists_on_device $device_id $PACKAGE; then    
                print_error $device_name " - Target app isn't installed on the device, install it on the device first"
                exit
            fi
            

            start_log $device_id $device_name

            start_app_on_device $device_id $device_name $PACKAGE
            # TODO: start a screen recording, copy recording when run is done
            # TODO: check app active activity when run is done
        done

        wait_for_target_app_launch
        kill_all_logs

        for (( i=0; i<${#DEVICE_ID_LIST[@]}; i++ ));
        do
            device_id=${DEVICE_ID_LIST[$i]}
            device_name="${DEVICE_MODEL_LIST[$i]}"

            kill_app_on_device $device_id $device_name $PACKAGE

            # Check the log for crash evidence. You can add your own conditions for
            # abnormal behavior detection
            parse_logs $device_id $device_name

            copy_log $device_name 
        done

        ((PER_INTSALL_COUNTER=PER_INTSALL_COUNTER+1))
        if [ ${PER_INTSALL_COUNTER} -gt ${MAX_ROUNDS_PER_INSTALL} ]; then
            break
        fi
    done
        if [ ${PER_INTSALL_COUNTER} -gt ${MAX_ROUNDS_PER_INSTALL} ]; then
            print_section "Completed " ${MAX_ROUNDS_PER_INSTALL} "the number of launches has done for " ${PACKAGE}
            break
        fi
done
exit
