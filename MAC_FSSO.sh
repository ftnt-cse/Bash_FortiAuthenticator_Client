#!/bin/bash
declare -x PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
#Global VARS
TMP="/tmp/buffer"
LIST="/tmp/list"
USERS="/tmp/users"
FACIP="198.51.100.32"
FACAPIKEY="Ily5ZHMmLuiQUqDVoSPQ87jmlZ8knLEqqUvR5GVp"
FACUSERNAME="admin"

NETSTAT="/usr/sbin/netstat"
CURL="/usr/bin/curl"

#Function libs
#@
#@ Process logged users
#@
function ParseLogin(){
#init
echo > $LIST

myIP=$(ifconfig $($NETSTAT -rn | grep default | awk '{print $6}')| grep "inet " | awk '{ print $2}')
last | grep "logged in" | cut -b1-34 > $TMP 
echo $file

while IFS=' ' read -r f1 f2 f3
do
#trim spaces
f1="${f1##*( )}"
f1="${f1%%*( )}"
f2="${f2##*( )}"
f2="${f2%%*( )}"
f3="${f3##*( )}"
f3="${f3%%*( )}"

if [ -z "$f3" ];then
f3="$myIP"
f2="local"
else
f2="remote"
fi
#avoid system users
if [[ $f1 == _* ]];then
 continue
fi

printf '%s,%s,%s\n' "$f1" "$f2" "$f3" >> $LIST

done <"$TMP"
sort $LIST | uniq > $USERS
sed -i '' -e 's/^ *//; s/ *$//; /^$/d' $USERS
rm $LIST
rm $TMP
}

#@
#@ Process logged off users
#@
function ParseLogoff(){

[ ! -f "$USERS" ] && touch $USERS

while IFS=',' read -r f1 f2 f3
do
USERNAME="$f1"
GROUP="$f2"
IP="$f3"

#check whether the user is still logged in
if [ "$f2" == "local" ];then
LOGGEDIN=$(last | grep -vE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep "logged in" | grep $f1)
else
LOGGEDIN=$(last | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep "logged in" | grep $f1)
fi

if [ -z "$LOGGEDIN" ];then
echo $f1,$f2,$f3 is OFF
#update FAC with the logged in/off users
$CURL -k -v -u "$FACUSERNAME:$FACAPIKEY" -d '{"event":"0","username":"'"$USERNAME"'","user_ip":"'"$IP"'"}' -H "Content-Type:application/json" https://$FACIP/api/v1/ssoauth/
sleep 2
else
echo $f1,$f2,$f3 is ON
$CURL -k -v -u "$FACUSERNAME:$FACAPIKEY" -d '{"event":"1","username":"'"$USERNAME"'","user_ip":"'"$IP"'","user_groups":"'"$GROUP"'"}' -H "Content-Type:application/json" https://$FACIP/api/v1/ssoauth/
sleep 2
fi

done <"$USERS"
}

while true
do
date "+%H:%M:%S" >> /tmp/logs.txt
ParseLogoff >> /tmp/logs.txt
ParseLogin >> /tmp/logs.txt
sleep 30
done