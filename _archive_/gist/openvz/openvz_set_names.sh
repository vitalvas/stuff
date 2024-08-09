#!/bin/bash

old_IFS=$IFS
IFS=$'\n'

filter() { cat; }

for line in $(vzlist -H  -s veid -a -o veid,hostname)
do
    veid=`echo $line | filter | awk '{print $1}'`
    name=`echo $line | filter | awk '{gsub(/\./,"_",$2); print $2}'`
    vzctl set $veid --name $name --save > /dev/null
done                                                           

IFS=$old_IFS   
