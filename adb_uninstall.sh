#!/bin/bash
let i=0
bundle_id=$1
  while read line #get devices list
  do
    if [ -n "$line" ] && [ "`echo $line | awk '{print $2}'`" == "device" ]
    then
      device="`echo $line | awk '{print $1}'`"
      arr[i]="$device" # $ is optional
      let i=$i+1
    fi
  done < <(adb devices)

echo ${arr[*]}
for device in ${arr[*]}
do
    if [[ -n "$bundle_id" ]]; then
     adb -s $device uninstall $bundle_id
    fi
done
exit
