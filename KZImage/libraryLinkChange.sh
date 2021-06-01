#!/bin/bash

while read -d $'\0' file; do
otool -L "${file}" | grep -v "$(otool -D ${file})" | egrep -v "(usr/lib|System)" | cut -d' ' -f1 | while read
 do
  (install_name_tool -change "$(echo ${REPLY} | tr -d " ")" "@rpath/${REPLY##*/}" "${file}")
 done
done < <(find "$1" -mindepth 1 -maxdepth 1 -type f -print0)
