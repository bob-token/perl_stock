#!/usr/bin/bash
#connect network
#ping -c 1 www.google.com
#echo $?
#while [ $?>0 ];do
#netcfg wlan_dlink
#sleep 10
#ping -c 1 www.google.com
#done
#cmd
 while [ 1 ];do  git pull; sh usr_command_deamon.sh > usr_command_deamon.log 2>&1;echo>usr_command_deamon.sh; git commit -a -m'usr_commoand_deamon'; git push; sleep 2; done
