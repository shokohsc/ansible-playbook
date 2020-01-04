#!/bin/bash
#
# Watch your Pi! RPi foundation knows that Micro USB for DC-IN
# is sh*t but also doesn't give a sh*t. Voltage drops caused by
# average USB cables cause all sorts of instabilities and also
# data corruption but instead of fixing the problem they masked
# it in their 'firmware'. The main CPU on the Raspberry monitors
# voltage drops and then acts on accordingly. If heavy voltage
# drops directly after startup are monitored the firmware lowers
# the core voltage available to CPU cores and also caps CPU
# clockspeed. If voltage drops aren't that severe a more flexible
# approach is used and at least you gain performance back after
# periods of heavy load.
#
# The monitoring script prints SoC temperature, sysfs clockspeed
# (and real clockspeed if differing -- this can happen!),
# 'vcgencmd get_throttled' bits and core voltage. To interpret
# the 'get_throttled' bits please refer to this (based on tests
# on RPi 3 descriptions for bits 1/2 and 17/18 should be exchanged!)
#
# 0: under-voltage
# 1: arm frequency capped
# 2: currently throttled
#
# 16: under-voltage has occurred
# 17: arm frequency capped has occurred
# 18: throttling has occurred
#
# Background info: http://preview.tinyurl.com/mmwjfwy and
# http://tech.scargill.net/a-question-of-lifespan/
#
# With a crappy PSU and/or Micro USB cable output looks like this
# on a RPi 3:
#
# 44.0'C  600 MHz 1010000000000000000 1.2V
# 44.5'C  600 MHz 1010000000000000000 1.2V
# 44.0'C  600 MHz 1010000000000000101 1.2V
# 44.0'C  600 MHz 1010000000000000101 1.2V
# 44.0'C  600 MHz 1010000000000000101 1.2V
# 44.5'C  600 MHz 1010000000000000000 1.2V
# 45.1'C  600 MHz 1010000000000000101 1.2V
#
# With an ok-ish cable it looks like this (when running cpuburn-a53):
#
# 48.3'C 1200 MHz 0000000000000000000 1.3312V
# 48.3'C 1200 MHz 0000000000000000000 1.3312V
# 48.3'C 1200 MHz 0000000000000000000 1.3312V
# 48.3'C 1200 MHz 0000000000000000000 1.3312V
# 50.5'C 1200 MHz 0000000000000000000 1.3312V
# 56.4'C  600 MHz 0000000000000000000 1.2V
# 54.8'C  600 MHz 1010000000000000101 1.2V
# 55.3'C  600 MHz 1010000000000000101 1.2V
# 55.8'C  600 MHz 1010000000000000101 1.3312V
# 53.7'C  600 MHz 1010000000000000101 1.2V
# 51.5'C  600 MHz 1010000000000000101 1.2V
# 51.0'C  600 MHz 1010000000000000101 1.2V
#
# And only by bypassing the crappy connector you can enjoy RPi 3
# performing as it should (please note, there's a heatsink on my RPi
# -- without throttling would start and then reported clockspeed
# numbers start to get funny):
#
# 75.2'C 1200 MHz 1010000000000000000 1.3250V
# 75.8'C 1200 MHz 1010000000000000000 1.3250V
# 75.8'C 1200 MHz 1010000000000000000 1.3250V
# 76.3'C 1200 MHz 1010000000000000000 1.3250V
# 76.3'C 1200 MHz 1010000000000000000 1.3250V
# 73.6'C 1200 MHz 1010000000000000000 1.3250V
# 72.0'C 1200 MHz 1010000000000000000 1.3250V
# 70.4'C 1200 MHz 1010000000000000000 1.3250V
#
# Now with a pillow on top for some throttling:
#
# 82.2'C 1200/ 947 MHz 1110000000000000010 1.3250V
# 82.7'C 1200/ 933 MHz 1110000000000000010 1.3250V
# 82.7'C 1200/ 931 MHz 1110000000000000010 1.3250V
# 82.7'C 1200/ 918 MHz 1110000000000000010 1.3250V
# 82.2'C 1200/ 935 MHz 1110000000000000010 1.3250V
# 79.9'C 1200/1163 MHz 1110000000000000000 1.3250V
# 75.8'C 1200 MHz 1110000000000000000 1.3250V
#
# And here on RPi 2 with crappy USB cable and some load
#
# 50.8'C  900 MHz 1010000000000000000 1.3125V
# 49.8'C  900 MHz 1010000000000000000 1.3125V
# 49.8'C  900/ 600 MHz 1010000000000000101 1.2V
# 49.8'C  900/ 600 MHz 1010000000000000101 1.2V
# 48.7'C  900/ 600 MHz 1010000000000000101 1.2V
# 49.2'C  900/ 600 MHz 1010000000000000101 1.2V
# 48.7'C  900 MHz 1010000000000000000 1.3125V
# 46.5'C  900 MHz 1010000000000000000 1.3125V
#
# The funny thing is that while the kernel thinks it's running
# with 900 MHz (performance governor) in reality the 'firmware'
# throttles down to 600 MHz but no one knows :)

echo -e "To stop simply press [ctrl]-[c]\n"
Maxfreq=$(( $(awk '{printf ("%0.0f",$1/1000); }'  </sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq) -15 ))
while true ; do
	Health=$(perl -e "printf \"%19b\n\", $(vcgencmd get_throttled | cut -f2 -d=)")
	Temp=$(vcgencmd measure_temp | cut -f2 -d=)
	RealClockspeed=$(vcgencmd measure_clock arm | awk -F"=" '{printf ("%0.0f",$2/1000000); }' )
	SysFSClockspeed=$(awk '{printf ("%0.0f",$1/1000); }' </sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
	CoreVoltage=$(vcgencmd measure_volts | cut -f2 -d= | sed 's/000//')
	if [ ${RealClockspeed} -ge ${Maxfreq} ]; then
		echo -e "${Temp}$(printf "%5s" ${SysFSClockspeed}) MHz $(printf "%019d" ${Health}) ${CoreVoltage}"
	else
		echo -e "${Temp}$(printf "%5s" ${SysFSClockspeed})/$(printf "%4s" ${RealClockspeed}) MHz $(printf "%019d" ${Health}) ${CoreVoltage}"
	fi
	sleep 5
done
