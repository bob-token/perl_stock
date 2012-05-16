#coding=utf-8
from __future__ import with_statement #在Python2.5中使用with的话需要这么干
from PyWapFetion import *
import sys
#仅作参考，详细了解请参考源码

#快速发送：
if len(sys.argv)==4:
	send2self(sys.argv[1],sys.argv[2],sys.argv[3])
elif len(sys.argv)==5:
	send(sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4])
