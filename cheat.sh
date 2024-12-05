#!/bin/bash

export SEXPECT_SOCKFILE=/tmp/sexpect-sonoff-$$.sock

type -P sexpect >& /dev/null || exit 1


sexpect spawn -idle 10 -timeout 600 ./readoz.sh

lasthour=0
temp=
droptemp=0
bumpup=0
setback=1

settemp()
{
    echo settemp $1 $2
    curl -s -d "$1-THERMOSTAT SETPOINT-user-decimal-1-1=$2" -X POST http://192.168.10.145:8091/valuepost.html
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
        elif [[ $out == *Class\ THERMOSTAT\ OPERATING\ STATE\ * ]]; then
	    state=${out##*ValueAsString} 
        elif [[ $out == *Class\ THERMOSTAT\ SETPOINT\ * ]]; then
	    setpoint=${out##*ValueAsString} 
            setpoint=${setpoint%%.*}
	    setpts[$node]=$setpoint
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

    today=`date +%d`
    hour=`date +%H`
    day=`date +%a`
    # usbtemp=`digitemp_DS9097 -q -t 0 -c .digitemprc`

    if [ $lasthour != $hour ] ; then
	lasthour=$hour
	echo $day $hour
	if [ $day != "Sun" ] && [ $hour = "04" -o $hour = "16" ]  ; then
	    echo "bump up"
            echo "temp" $temp
	    bumpup=1
            for i in ${!ttemps[@]}; do
                echo "ttemp" $i ${ttemps[$i]}
            done

            for i in ${!setpts[@]}; do
		setpoint=${setpts[$i]}
                echo "setpt" $i $setpoint
		old_setpts[$i]=$setpoint

		if [ $setpoint = "58" ] ; then
			setpoint=72
		else
			setpoint=$((setpoint + 3))
		fi
		settemp $i $setpoint
		save_setpts[$i]=$setpoint
            done
	fi

	if [ $day != "Sun" ] && [ $bumpup = 1 ] && [ $hour = "06" -o $hour = "17" ]  ; then
	    echo "bump down"
	    bumpup=0

            for i in ${!old_setpts[@]}; do
		 if [ $save_setpts[$i] = $setpts[$i] ] ; then
		    settemp $i ${old_setpts[$i]}
		 fi
	    done
	fi

        # echo "usb temp $usbtemp"

        # if [[ "$temp" = "" ]] ; then
         #    usbtemp=${usbtemp##*F:}
          #   temp=$usbtemp
       #  fi
        tempint=${temp%.*}


        # check vrc
	vrc=`wget -q -O- http://voicedatac.com:8102/behrsj/cgi-bin/vrc.php | grep rented`

        # if unit is not rented today, turn down the thermostat
	if [ "$vrc" = "not rented" ] && [ $hour = "11" ] ; then
	    setback=1
            for i in ${!setpts[@]}; do
		settemp $i 45
	    done
	fi

	if [ "$vrc" = "rented" ] && [ $hour = "09" ] && [ $setback = "1" ] ; then
	    setback=0
            for i in ${!setpts[@]}; do
		settemp $i 68
	    done
	fi
    fi

done
