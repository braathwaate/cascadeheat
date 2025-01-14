#!/bin/bash

while true
do
	killall cheat.sh
	killall readoz.sh
	killall grep
	killall sexpect
	./cheat.sh
	if [ $? -ne 204 ] ; then
		exit
	fi
done
