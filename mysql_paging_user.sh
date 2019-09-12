#!/bin/bash
net_type="1191336"
t_date=`date +%s`
serial_num=00000
s_code="WA_BASIC_0009"
sq="0"

f_page () {
  p_start="10000"
  p_end="15000"
  p_total="30000"

  while [ $p_start -le $p_total ];do
    serial_num=$((10#$serial_num+1))
    serial_num=`printf "%05d" $serial_num`

    #echo $p_start $p_end >/tmp/${net_type}-${t_date}-${serial_num}-${s_code}-$sq.bcp
    mysql -S mysql.sock -Ne "use testdb;select a.id,a.phone account,b.nickname,a.create_time from users a join users_info b on a.id=b.user_id where a.id between $p_start and $p_end;" >/tmp/${net_type}-${t_date}-${serial_num}-${s_code}-$sq.bcp
    sleep 1;

    p_start=$((p_start+5000))
    p_end=$((p_end+5000))

  done
}
