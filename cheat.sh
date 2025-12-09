#!/bin/bash

export SEXPECT_SOCKFILE=/tmp/sexpect-sonoff-$$.sock

type -P sexpect >& /dev/null || exit 1


sexpect spawn -idle 10 -timeout 600 ./readoz.sh

lasthour=0
temp=
droptemp=0
bumpup=0
setback=1
vrc="unknown"

settemp()
{
    echo settemp $1 $2
    curl -s -d "$1-THERMOSTAT SETPOINT-user-decimal-1-1=$2" -X POST http://127.0.0.1:8091/valuepost.html
}

bumpdown()
{
    bumpup=0
    echo "bump down"

    for i in ${!old_setpts[@]}; do
	 if [ ${save_setpts[$i]} = ${setpts[$i]} ] ; then
	    settemp $i ${old_setpts[$i]}
	 fi
    done
}

while true
do
    errmsg=`sexpect expect -cstr -re '[^\n\r]*ValueAsString[^\n\r]*' 2>&1`
    ret=$?
    if [[ $ret == 0 ]]; then
        out=$( sexpect expect_out )
	# d=${out%%ubuntu*}
	d=${out%%Info*}
	node=${out##*Node} 
        node=${node%%Genre*}
        if [[ $out == *Node\ 1\ *Index* ]]; then
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
        elif [[ $out == *Node\ 22*Class\ BATTERY* ]]; then
	    batt=${out##*ValueAsString} 
	    echo "$d Lock Battery $batt"
        elif [[ $out == *Node\ 22*Class\ USER\ CODE* ]]; then
	    code=${out##*ValueAsString} 
	    echo "$d Lock Code $code"
        elif [[ $out == *Node\ 22*Class\ ALARM* ]]; then
	    alarm=${out##*ValueAsString} 
	    echo "$d Lock Alarm $alarm"
        elif [[ $out == *Node\ 22* ]]; then
	    lock=${out##*ValueAsString} 
	    echo "$d Lock $lock"
	    # send email when unit is locked or unlocked
	    if [ "$vrc" = "not rented" ] ; then
		    echo | mutt -s "Lock $lock at unit 59" -- behrsj@voicedata
	    fi
        elif [[ $out == *Class\ POWERLEVEL\ * ]]; then
	    pl=${out##*ValueAsString} 
	    echo "$d $node Power Level is $pl"
        elif [[ $out == *Class\ MANUFACTURER\ * ]]; then
	    mf=${out##*ValueAsString} 
	    echo "$d $node Manufacturer is $mf"
        elif [[ $out == *Class\ VERSION\ * ]]; then
	    ver=${out##*ValueAsString} 
	    echo "$d $node Version is $ver"
        elif [[ $out == *Class\ ZWAVE\ * ]]; then
	    zw=${out##*ValueAsString} 
	    echo "$d $node Zwave is $zw"
        elif [[ $out == *Class\ THERMOSTAT\ MODE\ * ]]; then
	    mode=${out##*ValueAsString} 
        elif [[ $out == *Class\ THERMOSTAT\ OPERATING\ STATE\ * ]]; then
	    state=${out##*ValueAsString} 
        elif [[ $out == *Class\ THERMOSTAT\ SETPOINT\ * ]]; then
	    setpoint=${out##*ValueAsString} 
            setpoint=${setpoint%%.*}
	    setpts[$node]=$setpoint
	    echo "$d $node Thermostat Setpoint is $setpoint"

	    # send email if high setpoint is set when unoccupied
	    # do not automatically override
	    # because of rental not on calendar (late exit, unscheduled use, etc)
	    # manual investigation is required
	    if [ $setpoint -gt 68 ] && [ "$vrc" = "not rented" ] ; then
		    echo | mutt -s "High Setpoint $node $setpoint at unit 59" -- behrsj@voicedata
	    fi
        elif [[ $out == *Class\ SENSOR\ *Index\ 1\ * ]]; then
	    ttemp=${out##*ValueAsString} 
	    ttemps[$node]=$ttemp

	    # this automatically adds the node to the setpoint list
	    # useful after a restart
	    if [ "${setpts[$node]}" = "" ]; then
		    echo Found $node.  Added setpoint 68.
		    setpts[$node]=68
	    fi
        else
            echo "unknown ValueAsString: $out"
        fi
    elif sexpect chkerr -errno $ret -is timeout; then
          # Timed out waiting for the expected output
	  # clear temp to use usbtemp later
	  temp=
    else
	 echo $errmsg
	 echo "rc=$ret"
	 ps -fu ubuntu
	 if [ $bumpup = 1 ] ; then
		 bumpdown
	 fi
	 exit $ret
    fi

    # testing
    # continue

    today=`date +%d`
    hour=`date +%H --date="10 minutes today"`
    day=`date +%a`
    mon=`date +%m`
    # usbtemp=`digitemp_DS9097 -q -t 0 -c .digitemprc`

    if [ $lasthour != $hour ] ; then
	lasthour=$hour
	echo $day $hour

	# echo "usb temp $usbtemp"

	# if [[ "$temp" = "" ]] ; then
	#    usbtemp=${usbtemp##*F:}
	#   temp=$usbtemp
        # fi
	tempint=${temp%.*}

        # check vrc
	if [ -f voicedata ] ; then
		vrc=`wget -q -O- http://voicedata/behrsj/cgi-bin/vrc.php | grep rented`
	else
		vrc="unknown"
		setback=0
	fi


	# change thermstat setpoints during cold months
	if [ $mon = "11" -o $mon = "12" -o $mon = "01" -o $mon = "02" -o $mon = "03" -o $mon = "04" ] ; then

	    # if unit is not rented today, prepare turn down the thermostat
	    # keeping the heat on until next peak for housekeeping
	    if [ "$vrc" = "not rented" ] && [ $setback = "0" ] && [ $hour = "16" ] ; then
	        setback=1
	    fi

	    # As soon as the unit shows as rented for the day, raise the temperature to 68 degrees
	    # Normally this is midnight for reservations made in advance
	    # This will easily get the condo up to temperature by noon.
	    if [ "$vrc" = "rented" ] && [ $setback = "1" ] ; then
	        setback=0
	        for i in ${!setpts[@]}; do
		    settemp $i 68
	        done
	    fi

	    if [ $hour = "04" -o $hour = "16" ]  ; then
	        for i in ${!ttemps[@]}; do
		    echo "ttemp" $i ${ttemps[$i]}
	        done
	        echo "temp" $temp

		if [ -f setbacks ] && [ $day != "Sun" ] ; then
		    echo "bump up"
		    bumpup=1

		    for i in `cat setbacks`
		    do
			    setpts[$i]=setback
		    done

		    for i in ${!setpts[@]}; do
			setpoint=${setpts[$i]}

			if [ $setpoint = "setback" ] ; then
				old_setpts[$i]=58
				setpoint=72
			else
				old_setpts[$i]=$setpoint
				setpoint=$((setpoint + 3))
			fi
			settemp $i $setpoint
			save_setpts[$i]=$setpoint
		    done
		elif [ $setback = "1" ] ; then
			# if not rented
			# force 50 degrees at 4 PM peak each day
			# in order to thwart the cleaning staff
			# and at 4 AM thereafter
			# note if rented, do not muck with setpoints
		    echo "bump up"
		    bumpup=1

		    for i in ${!setpts[@]}; do
			old_setpts[$i]=45
			settemp $i 50
			save_setpts[$i]=50
		    done
		fi
	    fi
	fi

	if [ $bumpup = 1 ] && [ $hour = "06" -o $hour = "17" ]  ; then
	    bumpdown
	fi

    fi

done
