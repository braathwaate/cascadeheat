#!/bin/bash

export SEXPECT_SOCKFILE=/tmp/sexpect-sonoff-$$.sock

type -P sexpect >& /dev/null || exit 1


sexpect spawn -idle 10 -timeout 600 ./readoz.sh

lasthour=0
temp=
droptemp=0
bumpup=0
setback=0

settemp()
{
    echo settemp $1 $2
    curl -s -d "$1-THERMOSTAT SETPOINT-user-decimal-1-1=$2" -X POST http://192.168.10.145:8091/valuepost.html
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
	    if [ $setpoint -gt 68 ] && [ $setback = "1" ] ; then
		    echo "Attempted high setpoint override"
		    settemp $node 68
	    fi
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
    hour=`date +%H`
    day=`date +%a`
    mon=`date +%m`
    # usbtemp=`digitemp_DS9097 -q -t 0 -c .digitemprc`

    if [ $lasthour != $hour ] ; then
	lasthour=$hour
	echo $day $hour
	if [ $mon = "11" -o $mon = "12" -o $mon = "01" -o $mon = "02" -o $mon = "03" -o $mon = "04" ] \
	    && [ $hour = "04" -o $hour = "16" ]  ; then
	    for i in ${!ttemps[@]}; do
		echo "ttemp" $i ${ttemps[$i]}
	    done
	    echo "temp" $temp

		if [ -f setbacks ] ; then
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
		elif [ $day != "Sun" ] ; then
		    echo "bump up"
		    bumpup=1

		    for i in ${!setpts[@]}; do
			setpoint=${setpts[$i]}

			# rental day, but not yet 9 AM
			# get a jump on raising the temperature at 9 AM
			if [ "$vrc" = "rented" ] && [ $setback = "1" ] ; then
				old_setpts[$i]=45
				setpoint=68
			# not rented, after 11 AM of first day
			# this lowers temps before peak each day
			# in order to thwart the cleaning staff
			elif [ $setback = "1" ] ; then
				old_setpts[$i]=45
				setpoint=48
			else
				old_setpts[$i]=$setpoint
				setpoint=$((setpoint + 3))
			fi
			settemp $i $setpoint
			save_setpts[$i]=$setpoint
		    done
		fi
	fi

	if [ $bumpup = 1 ] && [ $hour = "06" -o $hour = "17" ]  ; then
	    bumpdown
	fi

        # echo "usb temp $usbtemp"

        # if [[ "$temp" = "" ]] ; then
         #    usbtemp=${usbtemp##*F:}
          #   temp=$usbtemp
       #  fi
        tempint=${temp%.*}


        # check vrc
	vrc=`wget -q -O- http://voicedata/behrsj/cgi-bin/vrc.php | grep rented`

        # if unit is not rented today, prepare turn down the thermostat
	# keeping the heat on until next peak for housekeeping
	if [ "$vrc" = "not rented" ] && [ $hour = "11" ] ; then
	    setback=1
	fi

	if [ "$vrc" = "rented" ] && [ $hour = "09" ] && [ $setback = "1" ] ; then
	    setback=0
            for i in ${!setpts[@]}; do
		settemp $i 68
	    done
	fi
    fi

done
