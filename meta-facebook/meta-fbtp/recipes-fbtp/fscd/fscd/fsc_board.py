# Copyright 2015-present Facebook. All Rights Reserved.
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
#
from fsc_util import Logger
from subprocess import Popen, PIPE


def board_fan_actions(fan, action='None'):
    '''
    Override the method to define fan specific actions like:
    - handling dead fan
    - handling fan led
    '''
    Logger.warn("%s needs action %s" % (fan.label, str(action),))
    pass


def board_host_actions(action='None', cause='None'):
    '''
    Override the method to define fan specific actions like:
    - handling host power off
    - alarming/syslogging criticals
    '''
    Logger.warn("Host needs action %s and cause %s" % (str(action),str(cause),))
    pass


def board_callout(callout='None', **kwargs):
    '''
    Override this method for defining board specific callouts:
    - Exmaple chassis intrusion
    '''
    if 'read_power' in callout:
        return bmc_read_power()
    elif 'init_fans' in callout:
        boost = 100 # define a boost for the platform or respect fscd override
        if 'boost' in kwargs:
            boost = kwargs['boost']
        Logger.info("FSC init fans to boost=%s " % str(boost))
        return set_all_pwm(boost)
    pass


def set_all_pwm(boost):
    cmd = ('/usr/local/bin/fan-util --set %d' % (boost))
    response = Popen(cmd, shell=True, stdout=PIPE).stdout.read()
    return response


def bmc_read_power():
    cmd = '/usr/local/bin/power-util mb status'
    data = Popen(cmd, shell=True, stdout=PIPE).stdout.read()
    if 'ON' in data:
        return 1
    else:
        return 0
