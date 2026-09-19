#! /bin/bash

read -sp "New Password: " new_pw
echo ""

read -sp "Confirm: " confirm
echo ""

if [[ $new_pw != $confirm ]];then
	echo "Passwords do not match"
	exit 1
fi

while IFS= read -r line;do
	if ! echo $line | cut -d ':' -f 2 | grep -q "^!";then
		USER=$(echo $line | cut -d ':' -f 1)
		echo "$USER:$new_pw" | chpasswd
		echo "$USER,$new_pw"
	fi
done < /etc/shadow
