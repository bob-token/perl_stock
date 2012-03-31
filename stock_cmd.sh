while [ 1 ];do git pull; sh usr_command.sh>>usr_command.log 2>&1 ; echo>usr_command.sh; git commit -a -m'usr_command';git push; sleep 1; done

