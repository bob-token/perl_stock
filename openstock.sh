#!/bin/bash
while read line 
do
	url="http://finance.sina.com.cn/realstock/company/sz002095/nc.shtml"
	cnt=`expr match "$line" 'select'` 
	if [[ $cnt > 0 ]];
	then
		begin=1	
		continue
	fi

	if [[ $begin > 0 ]];then
		code=${line:0:8}
		if [[ $code =~ s[zh] ]];then
			#firefox  ${url/sz002095/$code}
			chromium ${url/sz002095/$code}
		fi
	fi
done < log_txt
