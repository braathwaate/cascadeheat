#!/bin/bash

while true
do
	killall cheat.sh
	killall readoz.sh
	killall grep
	killall sexpect
	ping -c 3 voicedata
	if [ $? = 0 ] ; then
		touch voicedata
	else
		rm -f voicedata
	fi
	./cheat.sh
	if [ $? -ne 204 ] ; then
		exit
	fi
	sleep 3600
done
