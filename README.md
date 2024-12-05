# Overview

This is a shell script with the main purpose
of automatically changing the setpoints of zwave electric baseboard thermostats based on the day and time
and whether the unit is occupied.
This is useful for cost-saving because of an extreme time-of-use pricing differential.

# Software Requirements

* ubuntu 20 server
* open-zwave
* open-zwave-control-panel
* https://github.com/clarkwang/sexpect
* apache2 (needed for port forwarding for remote access)

# Hardware Requirements

* Raspberry Pi 3+
* AEON Labs ZW090 Z-Stick Gen5 EU
* Stelpro STZW402+ Electronic Thermostat
* Aeotec Limited ZWA009 AërQ Temperature & Humidity Sensor
* Schlage (Allegion) BE469ZP Connect Smart Deadbolt

# Installation Notes

ozwcp is run as a service

vi /etc/systemd/system/ozwcp.service
[Unit]
Description=OpenZWave Control Panel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/ubuntu/open-zwave-control-panel
ExecStart=/home/ubuntu/open-zwave-control-panel/ozwcp -p 8091 -c /home/ubuntu/config > /home/ubuntu/open-zwave-control-panel/OZW2_Log.txt
Restart=on-failure

[Install]
WantedBy=multi-user.target

if necessary, use sudo service ozwcp restart

/etc/rsyslog.d/10-ozwcp.conf

if ( $programname == "ozwcp" ) then {
    action(type="omfile" file="/var/log/ozwcp.log" flushOnTXEnd="on")
    stop
}

The debug log is in /var/log/ozwcp.log

The output log is in /home/ubuntu/open-zwave-control-panel/OZW2_Log.txt.
This is used by readoz.sh instead of ozwcp.log because it is much shorter
and doesn't get moved around by the log daemon.

If the z-wave hub is reset, all the devices need to be added again.
To add a device, use the web page and Add Device.

To add the thermostat,
press both buttons for 3 seconds, then press them again to activate the inclusion,
up button, and then press both buttons again to accept the change.
Then the ON will flash rapidly.

To add the Aeotec aërQ
1 short press used for immediate report
3 short press used to pair and unpair

Remove the battery cover of the deadbolt. 3.Press then release the button on the PCB.4.An LED will flash amber indicating the Add or Inclusion process is in progress. If the Security Scheme is Security 2 (S2), verify the DSK of the lock at the Z-Wave Controller. The PIN Code portion of the Z-Wave DSK will be needed.5.When a green LED turns ON, the Add or Inclusion has completed successfully. 6.If a red LED turns ON, try repeating steps


run testinit.sh to initialize ozwcp
then nohup ./cheat.sh &
