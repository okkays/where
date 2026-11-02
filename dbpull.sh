#!/bin/bash
rm -rf ./exported_dbs
mkdir -p ./exported_dbs

appname="$(cat android/app/build.gradle.kts | grep -E applicationId | sed 's/\s*applicationId\s*=\s*//')"

dbs="$(adb shell "run-as $appname find /data/data/$appname/databases/ -name '*.db'")"

for db in $(echo $dbs)
do
  dest="./exported_dbs/$(basename "$db")"
  echo "Copying '$db' to '$dest'"
  adb shell "run-as $appname cat $db" > $dest
done

