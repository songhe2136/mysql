#!/bin/bash

date=`date "+%Y%m%d-%H%M"`
myhost="$1"
myport="$2"
mytool="/usr/local/mysql/bin/mysql -h${myhost} -P${myport} -uxxx -pxxx"
stat_file="/home/shell/qcf_dbmonitor/slave_stat.$date"

recv_mail="zhangsonghe@huiyoujia.com,dev@huiyoujia.com"

echo "show slave status \G;"|${mytool}  >${stat_file}

io_thread=`grep Slave_IO_Running ${stat_file}|awk '{print $2}'`
sql_thread=`grep Slave_SQL_Running ${stat_file}|awk '{print $2}'`
last_errno=`grep Last_Errno ${stat_file}|awk '{print $2}'`
behind_master=`grep 'Seconds_Behind_Master' ${stat_file}|awk '{print $2}'`

chk_db_stat () {
if [ "${io_thread}" = "No" ] || [ "${sql_thread}" = "No" ];then
    if [ "${last_errno}" -eq 0 ];then
        echo "start io_thread;start sql_thread;"|${mytool}
        echo "$date"  "neterr Ran: start io_thread;start sql_thread;" >>/tmp/tmp.slave_stat.$date
    elif [ "${last_errno}" -eq 1062 ] || [ "${last_errno}" -eq 1153 ] || [ "${last_errno}" -eq 1158 ] || [ "${last_errno}" -eq 1159 ] || [ "${last_errno}" -eq 1007 ] || [ "${last_errno}" -eq 1008 ] || [ "${last_errno}" -eq 1213 ];then
        echo "stop slave;set global sql_slave_skip_counter=1;start slave"|${mytool}
        echo "$date"  "skiperr Ran: stop slave;set global sql_slave_skip_counter=1;start slave" >>/tmp/tmp.slave_stat.$date
    else
        echo "$date"  "${myhost} ${myport} Last_errno:${last_errno} mysql replication error!" >>/tmp/tmp.slave_stat.$date
    fi
else
    if [ ${behind_master} -gt 200 ];then
        echo "$date"  "Seconds_Behind_Master:${behind_master} please checkout!" >>/tmp/tmp.slave_stat.$date
    fi
fi
}

send_mail () {
sender="Mysql-Stat@huiyoujia.com"
mail_title="PROBLEM:mysql stats"
mail_date="$date"
addressee="${recv_mail}"

mail_format=$(cat <<!
Date: ${mail_date}
From: $sender
To: $addressee
Subject: ${mail_title}
Mime-Version: 1.0
Content-Type: text/html; charset=utf8
!)

echo "${mail_format}" >/tmp/tmp.slave_stat.$date.log
cat /tmp/tmp.slave_stat.$date >>/tmp/tmp.slave_stat.$date.log
cat /tmp/tmp.slave_stat.$date.log|/usr/sbin/sendmail -t
rm -rf /tmp/tmp.slave_stat.$date
rm -rf /tmp/tmp.slave_stat.$date.log
}

chk_db_stat
if [ -s "/tmp/tmp.slave_stat.$date" ];then send_mail;fi

rm -rf $stat_file

date "+%F/%X"
exit 0

#####
*/5 * * * * sh mysql_replication_stat.sh $ip $port >/dev/null 2>&1
