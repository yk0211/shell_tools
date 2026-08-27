#!/bin/bash

function deal_special_string()
{
	echo $1 | sed -e 's/[^a-zA-Z0-9,._+@%/-]/\\&/g; 1{$s/^$/""/}; 1!s/^/"/; $!s/$/"/'
}

function get_inet_addr()
{
	ifconfig eth0 | grep "inet addr:" | awk '{print $2}' | cut -c 6-
}

function push_by_scp()
{
/usr/bin/expect << EOF
	set timeout 10
	spawn scp -r -P $2 $5 ${3}@${1}:${6}
	expect {
		"(yes/no)?" { send "yes\n";exp_continue }
		"*password:" { send "$4\n" }
	}

	expect eof
EOF
}

function push_by_rsync()
{
/usr/bin/expect << EOF
	set timeout 10
	spawn rsync -avz --delete --progress --port=$2  $5 ${3}@${1}:${6}
	expect {

		"(yes/no)?" { send "yes\n";exp_continue }
		"*password:" { send "$4\n" }
	}

	expect eof
EOF
}

#param:$host $port $username $password $src_file $dst_file
function push_file()
{
	
	if [ ! -e $5 ]; then
		echo "$5 not exist!"
		exit 1
	fi

	local inet_addr="$(get_inet_addr)"
	local password="$(deal_special_string $4)"
	if [ $1 = $inet_addr ]; then
		cp -rf $5 $6
	else
		push_by_scp $1 $2 $3 $password $5 $6
	fi	
}
