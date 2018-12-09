#!/bin/bash
declare -x PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
#Global VARS
TMP="/tmp/buffer"
LIST="/tmp/list"
USERS="/tmp/users"
FACIP="198.51.100.32"
FACAPIKEY="REPLACE_WITH_FortiAuthenticator_API_KEY"
FACUSERNAME="admin"

NETSTAT="/bin/netstat"
CURL="/usr/bin/curl"

#Function libs
#
#@ Validate IP addresses
#
function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

#@
#@ Process logged users
#@
function ParseLogin(){
#init
echo > $LIST

myIP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
last | grep "logged in" | cut -b1-34 > $TMP 

while IFS=' ' read -r f1 f2 f3
do
#trim spaces
f1="${f1##*( )}"
f1="${f1%%*( )}"
f2="${f2##*( )}"
f2="${f2%%*( )}"
f3="${f3##*( )}"
f3="${f3%%*( )}"
#avoid system users
if [[ "$f1" == "reboot" ]];then
 continue
fi

if valid_ip $f3; then
f2="remote"
else
f3="$myIP"
f2="local"
fi

printf '%s,%s,%s\n' "$f1" "$f2" "$f3" >> $LIST

done <"$TMP"

#clean up
sort $LIST | uniq > $USERS
sed -i '/^$/d' $USERS
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
#$CURL -k -v -u "$FACUSERNAME:$FACAPIKEY" -d '{"event":"0","username":"'"$USERNAME"'","user_ip":"'"$IP"'"}' -H "Content-Type:application/json" https://$FACIP/api/v1/ssoauth/
sleep 2
else
echo $f1,$f2,$f3 is ON
#$CURL -k -v -u "$FACUSERNAME:$FACAPIKEY" -d '{"event":"1","username":"'"$USERNAME"'","user_ip":"'"$IP"'","user_groups":"'"$GROUP"'"}' -H "Content-Type:application/json" https://$FACIP/api/v1/ssoauth/
sleep 2
fi

done <"$USERS"
}

date "+%H:%M:%S" 
ParseLogoff
ParseLogin 
