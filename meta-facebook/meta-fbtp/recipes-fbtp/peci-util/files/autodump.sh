#!/bin/bash

PID=$$
# File format autodump<fru>.pid (See pal_is_crashdump_ongoing()
# function definition)
PID_FILE='/var/run/autodump1.pid'

# check if running auto dump
[ -r $PID_FILE ] && OLDPID=`cat $PID_FILE` || OLDPID=''

# Set current pid
echo $PID > $PID_FILE

# kill previous autodump if exist
if [ ! -z "$OLDPID" ] && (grep "autodump" /proc/$OLDPID/cmdline &> /dev/null) ; then
  echo "kill pid $OLDPID..."
  kill -s 9 $OLDPID
  killall peci-util &> /dev/null
  killall me-util &> /dev/null
fi
unset OLDPID

DUMP_SCRIPT='/usr/local/bin/dump.sh'
LOG_FILE='/tmp/autodump.log'
LOG_ARCHIVE='/mnt/data/autodump.tar.gz'
LOG_MSG_PREFIX=""

CPU0_SKTOCC_N="/sys/class/gpio/gpio51/value"
CPU1_SKTOCC_N="/sys/class/gpio/gpio208/value"
DWR=0
DELAY_SEC=30
SENSOR_HISTORY=180

while test $# -gt 0
do
  case "$1" in
  --dwr)
    DWR=1
    ;;
  --now)
    DELAY_SEC=0
    ;;
  *)
    echo "unknown argument $1"
    ;;
  esac
  shift
done

if [ "$DWR" == "1" ]; then
  LOG_ARCHIVE='/mnt/data/autodump_dwr.tar.gz'
  LOG_MSG_PREFIX="DWR "
  echo "Auto Dump after Demoted Warm Reset"
fi

if [ "$DELAY_SEC" != "0" ]; then
  echo "Auto Dump will start after ${DELAY_SEC}s..."

  sleep ${DELAY_SEC}
fi

echo "Auto Dump Started"

# Start to dump and clear LOG_FILE
echo -n "Auto Dump Start at " > $LOG_FILE
date >> $LOG_FILE

# CPU0
$DUMP_SCRIPT 48 coreid >> $LOG_FILE 2>&1
$DUMP_SCRIPT 48 msr >> $LOG_FILE 2>&1

# CPU1
if [ "`cat $CPU1_SKTOCC_N`" -eq "0" ]; then
  $DUMP_SCRIPT 49 coreid >> $LOG_FILE 2>&1
  $DUMP_SCRIPT 49 msr >> $LOG_FILE 2>&1
else
  echo "<<---------- CPU1 is not present, skip it. ---------->>" >> $LOG_FILE
fi

# PCIe
$DUMP_SCRIPT pcie >> $LOG_FILE 2>&1

# Sensors
echo "Sensor history of last ${SENSOR_HISTORY}s at dump:" >> $LOG_FILE 2>&1
/usr/local/bin/sensor-util all --history $SENSOR_HISTORY >> $LOG_FILE 2>&1

echo "Sensor threshold at dump: " >> $LOG_FILE 2>&1
/usr/local/bin/sensor-util all --threshold >> $LOG_FILE 2>&1

echo -n "Auto Dump End at " >> $LOG_FILE
date >> $LOG_FILE

tar zcf $LOG_ARCHIVE -C `dirname $LOG_FILE` `basename $LOG_FILE` && \
rm -rf $LOG_FILE && \
logger -t "ipmid" -p daemon.crit "${LOG_MSG_PREFIX}Crashdump for FRU: 1 is generated at $LOG_ARCHIVE"

# Remove current pid file
rm $PID_FILE

echo "${LOG_MSG_PREFIX}Auto Dump Stored in $LOG_ARCHIVE"
exit 0
