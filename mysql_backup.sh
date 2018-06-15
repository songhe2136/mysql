mysql 数据文件达到上百GB 的时候，mysqldump 备份恢复数据会非常非常慢。数据量大的时候不建议采用这种方式进行数据备份。
Percona开源 xtrabackup 工具则很好的解决了这个问题，不仅备份恢复快，并且支持流备份，增量备份。
原理不解释，直接上备份方案。

1.逻辑备份

#!/bin/bash

export PATH=$PATH:/usr/local/mysql/bin

#mysqlbump backup
host=$1
port=$2
db_name="select group_concat(SCHEMA_NAME SEPARATOR  ' ') from information_schema.SCHEMATA where SCHEMA_NAME like 'a%';"
#db_name="select group_concat(SCHEMA_NAME SEPARATOR  ' ') from information_schema.SCHEMATA where SCHEMA_NAME like 'i%' or SCHEMA_NAME like 'r%' or SCHEMA_NAME like 'pa%';"
dumptool="mysqldump -umydump -p123456"
dump_user="mysql -umydump -p123456"
date=`date +%Y%m%d%H%M`
del_date=`date -d "7 days ago" +%Y%m%d`
backup_dir=/data/mysqldump_backup

#del history backup
rm -rf ${backup_dir}/*$del_date*

#mysqlbump
mysqldump_backup () {
for myhost in $host;do
    for myport in $port;do
        for mydb_name in `$dump_user -h$myhost -P$myport -N -e "$db_name"`;do
            mkdir -p ${backup_dir}/${host}:${myport}_$date;
            cd ${backup_dir}/${host}:${myport}_$date;
            $dumptool -h$myhost -P$myport --quick --single-transaction --flush-logs --master-data -R -B ${mydb_name}|gzip  > ${mydb_name}.sql.gz
            continue
        done
    done
done   
}

mysqldump_backup

date +%F/%X
exit 0

##### $port 可以是数组，进行多实例备份 ######
crontab -l
10 01 * * * /home/shell/mysqlbackup.sh 10.10.3.233 "3306 3307" >/dev/null 2>&1 >> mysqlbackup.log &

2. 物理备份

# 增量备份，7天 合并一次全量。
#!/bin/bash

export PATH=$PATH:/disk3/mysql3320/bin

date=`date "+%F/%X"`
now_time=`date "+%Y-%m-%d"`
last_time=`date -d "1 days ago" "+%Y-%m-%d"`
union_time=`date -d "6 days ago" "+%Y-%m-%d"`
backup_dir="/disk3/xtrabackup"

#backup log
write_log () {
    loginfo=$1
    echo "`date "+%F/%X"`  $1" >> /home/shell/xtrabackup.sh.log
}

#xtrabackup
cd ${backup_dir}
if [ ! -d ${backup_dir}/full_backuped ];then
    mkdir -p full_backuped
#full-backuped
    innobackupex --user=xxx --password=xxx --port=3320 --host=192.168.2.235 --slave-info --no-timestamp --defaults-file=/disk3/mysql3320/my.cnf ${backup_dir}/full_backuped/${now_time}
    #stream_full-backup
    #innobackupex --user=backup --password=123456 --port=3307 --host=10.10.3.105 --no-timestamp --defaults-file=/data/mysql/mysql3307/my.cnf --slave-info --stream=xbstream --compress ${backup_dir} --extra-lsndir=${backup_dir}/full-backuped/${now_time} >${backup_dir}/full-backuped/${now_time}/full.xbstream
    innobackupex --apply-log --redo-only ${backup_dir}/full_backuped/${now_time};sleep 120
    write_log "full-backuped"
    innobackupex --user=xxx --password=xxx --port=3320 --host=192.168.2.235 --slave-info --no-timestamp --defaults-file=/disk3/mysql3320/my.cnf --incremental ${backup_dir}/${now_time} --incremental-basedir=${backup_dir}/full_backuped/${now_time}

#incremental-backuped
else
    #stream_incremental-backuped
    #innobackupex --user=backup --password=123456 --port=3307 --host=10.10.3.105 --no-timestamp --defaults-file=/data/mysql/mysql3307/my.cnf --slave-info --stream=xbstream --compress ${backup_dir} --incremental --incremental-basedir=${backup_dir}/${last_time} --extra-lsndir=${backup_dir}/${now_time} >/data/xtrabackup/2017-11-03/incremental.xbstream
    innobackupex --user=xxx --password=xxx --port=3320 --host=192.168.2.235 --slave-info --no-timestamp --defaults-file=/disk3/mysql3320/my.cnf --incremental ${now_time} --incremental-basedir=/data/xtrabackup/${last_time}
    write_log "incremental-backuped"
fi

#incremental-union-recovery
incr_sum=`ls ${backup_dir}|wc -l`
if [ ${incr_sum} -eq 8 ];then
    for incr_sam in `ls|grep -v full_backuped`;do
        innobackupex --apply-log --redo-only ${backup_dir}/full_backuped/{union_time} --incremental-dir=${backup_dir}/${incr_sam}
    done

mv full_backuped full_backuped_${now_time}
ls ${backup_dir}|grep -v full_backuped|xargs rm -rf
write_log "incremental-union-recovery"

#sendmail
echo "full_backuped_${now_time} completed OK!"|mail -s "xtrabaxkup-DUMPBD" "810485328@qq.com"
fi

#delete history backup
backup_sum=`ls ${backup_dir}|grep full_backuped |wc -l`
if [ ${backup_sum} -gt 3 ];then
    del_history_bk=`expr ${backup_sum} - 2`
    ls ${backup_dir}|grep full_backuped|head -n ${del_history_bk}|xargs rm -rf

write_log "delete history backup"
fi
    
exit 0

3. binlog日志 直接用 自带的mysqlbinlog 工具备份即可，没什么好说的。 

