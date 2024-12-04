#!/bin/bash

#opts="-n 400"
opts="-n 40"
#note: sexpect buffer overrun occurs without grep ValueAsString
#tail $opts --follow=name --retry /var/log/ozwcp.log | grep ValueAsString
tail $opts --follow=name --retry /home/ubuntu/open-zwave-control-panel/OZW2_Log.txt | grep ValueAsString
