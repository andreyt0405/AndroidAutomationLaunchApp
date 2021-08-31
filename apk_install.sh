#!/bin/bash
let i=0
apk_file=$1
bundle_id=$2
  while read line #get devices list
  do
    if [ -n "$line" ] && [ "`echo $line | awk '{print $2}'`" == "device" ]
    then
      device="`echo $line | awk '{print $1}'`"
      arr[i]="$device" # $ is optional
      let i=$i+1
    fi
  done < <(adb devices)

if [[ $(adb devices | grep -v "List of devices attached") ]]; then
        echo 'found connected device'
else
        exit 1
fi

for device in ${arr[*]}
do
    if [[ $(adb -s $device shell pm list packages | grep -i $bundle_id) ]]; then
        adb -s $device uninstall $bundle_id
    fi
     adb -s $device install $apk_file
done
exit
