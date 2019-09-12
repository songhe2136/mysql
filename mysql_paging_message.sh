#!/bin/bash
net_type="1191236"
t_date=`date +%s`
serial_num=00000
s_code="WA_SOURCE_0005"
sq="0"

f_page () {
  p_start="0"
  p_end="5000"
  p_total=`mysql -S /data/mysql/mysql3320/var/mysql.sock -Ne "use testdb;select max(id)-min(id) from qcf_messages where create_time between unix_timestam
p(concat(date_format(now(),'%Y-%m-%d'),' ','00:00:00'))*1000 and unix_timestamp(concat(date_format(now(),'%Y-%m-%d'),' ','23:59:59'))*1000;"`

  while [ $p_start -le $p_total ];do
    serial_num=$((10#$serial_num+1))
    serial_num=`printf "%05d" $serial_num`

    #echo $p_start $p_end >/root/tmp/${net_type}-${t_date}-${serial_num}-${s_code}-$sq.bcp
    mysql -S mysql.sock -Ne "use testdb;select a.sender_id,b.nickname s_nickname,c.phone s_phone,a.message_content,from_unixtim
e((a.create_time/1000),'%Y-%m-%d %T') send_time,a.reciever_id,e.nickname r_nickname,d.phone r_phone from messages a left join users_info b on a.sende
r_id = b.user_id left join users c on a.sender_id = c.id left join users d on a.reciever_id = d.id left join users_info e on a.reciever_id = e.us
er_id where a.create_time between unix_timestamp(concat(date_format(now(), '%Y-%m-%d'),' ','00:00:00'))*1000 and unix_timestamp(concat(date_format(now(),'%Y-
%m-%d'),' ','23:59:59'))*1000 limit $p_start,$p_end;" >/tmp/${net_type}-${t_date}-${serial_num}-${s_code}-$sq.bcp

    sleep 1;
    p_start=$((p_start+5000))
    p_end=$((p_end+5000))
  
  done
}

f_page
