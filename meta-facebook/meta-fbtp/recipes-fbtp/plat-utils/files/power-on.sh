#!/bin/sh
#
# Copyright 2014-present Facebook. All Rights Reserved.
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program in a file named COPYING; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA

### BEGIN INIT INFO
# Provides:          power-on
# Required-Start:
# Required-Stop:
# Default-Start:     S
# Default-Stop:
# Short-Description: Power on Server
### END INIT INFO
. /usr/local/fbpackages/utils/ast-functions

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

KEYDIR=/mnt/data/kv_store
DEF_PWR_ON=1
TO_PWR_ON=

check_por_config()
{

  TO_PWR_ON=-1

  # Check if the file/key doesn't exist
  if [ ! -f "${KEYDIR}/server_por_cfg" ]; then
    TO_PWR_ON=$DEF_PWR_ON
  else
    POR=`cat ${KEYDIR}/server_por_cfg`

    # Case ON
    if [ $POR == "on" ]; then
      TO_PWR_ON=1;

    # Case OFF
    elif [ $POR == "off" ]; then
      TO_PWR_ON=0;

    # Case LPS
    elif [ $POR == "lps" ]; then

      # Check if the file/key doesn't exist
      if [ ! -f "${KEYDIR}/pwr_server_last_state" ]; then
        TO_PWR_ON=$DEF_PWR_ON
      else
        LS=`cat ${KEYDIR}/pwr_server_last_state`
        if [ $LS == "on" ]; then
          TO_PWR_ON=1;
        elif [ $LS == "off" ]; then
          TO_PWR_ON=0;
        fi
      fi
    fi
  fi
  logger -s "TO_PWR_ON:$TO_PWR_ON, POR:$POR, LS:$LS"
}

# Sync BMC's date with the server
sync_date()
{
  # Use standard IPMI command 'get-sel-time' to read RTC time
  output=$(/usr/local/bin/me-util 0x28 0x48)
  # if the command fails, return
  [ $(echo $output | wc -c) != 12 ] && return
  col1=$(echo $output | cut -d' ' -f1 | sed 's/^0*//')
  col2=$(echo $output | cut -d' ' -f2 | sed 's/^0*//')
  col3=$(echo $output | cut -d' ' -f3 | sed 's/^0*//')
  col4=$(echo $output | cut -d' ' -f4 | sed 's/^0*//')

  # create the integer from the hex bytes returned
  val=$((0x$col4 << 24 | 0x$col3 << 16 | 0x$col2 << 8 | 0x$col1))

  # create the timestamp required for busybox's date command
  ts=$(date -d @$val +"%Y.%m.%d-%H:%M:%S")

  # set the command
  echo Syncing up BMC time with server...
  date $ts
}

# Check whether it is fresh power on reset
if [ $(is_bmc_por) -eq 1 ]; then

  sync_date

  check_por_config
  if [ $TO_PWR_ON -eq 1 ] ; then
    power-util mb on
  fi

fi