#!/bin/bash
let i=0
aab_file=$1
bundle_id=$2
file_output=$3
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
    echo $device
        bundletool build-apks --connected-device --device-id=$device --overwrite  --bundle=$aab_file --output=$file_output --ks=~/git/devenv/Certs/AndroidCertificate/appdome.keystore --ks-pass=pass:appdome --ks-key-alias=appdome --key-pass=pass:appdome
        bundletool install-apks --apks=$file_output --device-id=$device

done
exit
