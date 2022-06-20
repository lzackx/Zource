#! /bin/bash -ilex

nohup mongod 1>/dev/null 2>&1 &

cd /root/work/ZourceServer/

nohup npm start 1>/dev/null 2>&1 &

#npm start
