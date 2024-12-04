#!/bin/bash

export SEXPECT_SOCKFILE=/tmp/sexpect-sonoff-$$.sock

type -P sexpect >& /dev/null || exit 1


sexpect spawn -idle 10 -timeout 600 ./readoz.sh

lastchg=0
lasthour=0
temp=
droptemp=0

settemp()
{
    curl -s -d "2-THERMOSTAT SETPOINT-user-decimal-1-1=$1" -X POST http://192.168.10.145:8091/valuepost.html
}

while true
do
    sexpect expect -cstr -re '[^\n\r]*ValueAsString[^\n\r]*' > /dev/null
    ret=$?
    if [[ $ret == 0 ]]; then
        out=$( sexpect expect_out )
	# d=${out%%ubuntu*}
	d=${out%%Info*}
	node=${out##*Node} 
        node=${node%%Genre*}
        if [[ $out == *Node\ 1*Index* ]]; then
	    echo "$d Controller"
        elif [[ $out == *Node\ 3*Index\ 1\ * ]]; then
	    temp=${out##*ValueAsString} 
	    echo "$d Temperature is $temp"
        elif [[ $out == *Node\ 3*Index\ 5* ]]; then
	    hum=${out##*ValueAsString} 
	    echo "$d Humidity is $hum"
        elif [[ $out == *Node\ 3*Index\ 11\ * ]]; then
	    dew=${out##*ValueAsString} 
	    echo "$d Dew Point is $dew"
        elif [[ $out == *Node\ 3* ]]; then
	    val=${out##*ValueAsString} 
	    echo "$d Value $val"
        elif [[ $out == *Node\ 16*Class\ BATTERY* ]]; then
	    batt=${out##*ValueAsString} 
	    echo "$d Lock Battery $batt"
        elif [[ $out == *Node\ 16*Class\ USER\ CODE* ]]; then
	    code=${out##*ValueAsString} 
	    echo "$d Lock Code $code"
        elif [[ $out == *Node\ 16*Class\ ALARM* ]]; then
	    alarm=${out##*ValueAsString} 
	    echo "$d Lock Alarm $alarm"
        elif [[ $out == *Node\ 16* ]]; then
	    lock=${out##*ValueAsString} 
	    echo "$d Lock $lock"
	    # send email when unit is locked or unlocked
        elif [[ $out == *Class\ POWERLEVEL\ * ]]; then
	    pl=${out##*ValueAsString} 
	    echo "$d $node Power Level is $pl"
        elif [[ $out == *Class\ MANUFACTURER\ * ]]; then
	    mf=${out##*ValueAsString} 
	    echo "$d $node Manufacturer is $mf"
        elif [[ $out == *Class\ THERMOSTAT\ * ]]; then
	    setpoint=${out##*ValueAsString} 
	    echo "$d $node Thermostat Setpoint is $setpoint"
        elif [[ $out == *Class\ SENSOR\ *Index\ 1\ * ]]; then
	    ttemp=${out##*ValueAsString} 
	    ttemps[$node]=$ttemp
        else
            echo "unknown ValueAsString: $out"
        fi
    elif sexpect chkerr -errno $ret -is timeout; then
          # Timed out waiting for the expected output
	  # clear temp to use usbtemp later
	  temp=
    else
	    echo "rc=$ret"
    fi

    # testing
    # continue

    # turn down the heat at 11 am each day if unoccupied

    today=`date +%d`
    hour=`date +%H`
    # usbtemp=`digitemp_DS9097 -q -t 0 -c .digitemprc`

    if [ $lasthour != $hour ] && [ $hour = "10" ]  ; then
        echo "temp" $temp
        for i in ${!ttemps[@]}; do
            echo "ttemp" $i ${ttemps[$i]}
        done
        # echo "usb temp $usbtemp"

        # if [[ "$temp" = "" ]] ; then
         #    usbtemp=${usbtemp##*F:}
          #   temp=$usbtemp
       #  fi
        tempint=${temp%.*}

	lastchg=$today

        # check vrc
	vrc=`wget -q -O- http://voicedatac.com:8102/behrsj/cgi-bin/vrc.php | grep rented`

        # if unit is not rented today, turn down the thermostat
	if [ "$vrc" = "not rented" ] ; then
		settemp 45
	fi
    fi

done
