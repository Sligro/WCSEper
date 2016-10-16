#!/bin/bash

#####################################################################
# This script take care for switching the MQ Client in WCS in SO 3.0
# Author: B. Pittens
# Date: 14-10-2016
# Version 1.0.
#####################################################################

#logfile=/var/log/wcsswitchmq.log
logfile=~/wcsswitchmq.log

echo "start script on:" >> $logfile
echo $(date) >> $logfile

mqport=1414
sleepcheckconnection=3
sleepbeforeswitch=120

countnumbercalls=5


#MQ environment variables:
mq01="IMQ01.corp.accsligro.nl"
mq02="IMQ02.corp.accsligro.nl"

# read the default dns name in from the mqactivfile, if mqactivfile is not available an error will be logged

mqactiv=$(cat mqactivfile 2>> $logfile)

#jython files
jythontomq01="mqbacktoprimary.py"
jythontomq02="mqfailover.py"

# if there is no default mqactivfile or the contents is not correct then set it to var mq01 and create the mqactivfile

if [ "$mqactiv" != "$mq01" ] && [ "$mqactiv" != "$mq02" ]; then
mqactiv=$mq01
echo "Content of mqactivfile is not correct, set content mqactivfile to default:  $mqactiv" >> $logfile
echo "$mqactiv" > mqactivfile
fi


# loop 5 times to check if mq connection is available on var mqactiv. If connection is ok exit after 1 loop.
# if connection is not available check 5 times.

for (( i=1; i<=countnumbercalls; i++ ))
do
nc -z -v -w3 $mqactiv $mqport >> $logfile 2>> $logfile
result1=$?

echo "loopnr: $i" >> $logfile

        if [ "$result1" != 0 ]; then
        echo "port $mqport on $mqactiv is closed" >> $logfile
        else
        echo "port $mqport on $mqactiv is open" >> $logfile
        break
        fi

sleep $sleepcheckconnection

done

#if there is no connection switch the variable and switch the MQ connection on the WCS client.


if [ "$result1" != 0 ]; then

# wait time because if MQ is switching it is not possible to connect.

sleep $sleepbeforeswitch

# switch to the failover mq

        if [ "$mqactiv" == "$mq01" ]; then
        mqactiv=$mq02
 	jythonactiv=$jythontomq02
        echo "switched from IMQ01 to: $mqactiv" >> $logfile
        elif [ "$mqactiv" == "$mq02" ]; then
        mqactiv=$mq01
        jythonactiv=$jythontomq01
        echo "switched from IMQ02 to: $mqactiv" >> $logfile
        fi

# check if the chosen mq is up: It is possible that both mq managers are down.

        countnumbercorrectcalls=1
        for (( j=1; j<=countnumbercalls; j++ ))
        do
        nc -z -v -w3 $mqactiv $mqport >> $logfile 2>> $logfile
        result1=$?

        echo "loopnr: $j" >> $logfile

# only if the failover mq is available then a switch has to be done.

                if [ "$result1" == 0 ]; then
                echo "port $mqport on $mqactiv is open" >> $logfile
                let "countnumbercorrectcalls+=1"


# to exclude network failures check 5 times the connection before switch wcs client mq

                        if [ "$countnumbercalls" == "$countnumbercorrectcalls" ]; then
                        echo "wcs client mq is going to be switched" >> $logfile
                        # ./wsadmin.sh -lang jython -f ./$jythonactiv
                        ./$jythonactiv
                        echo "$mqactiv" > mqactivfile
                        break
                        fi

                fi


# if no connection can be made on both devices switch default mqactiv back to mq01

                if [ "$countnumbercalls" == "$j" ]; then
                mqactiv=$mq01
                echo "$mqactiv" > mqactivfile
                echo "No connection can be made, switched back to: $mqactiv" >> $logfile
                fi

                sleep $sleepcheckconnection

        done

fi

echo "end script" >> $logfile





