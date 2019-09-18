#!/usr/bin/ksh

if [ "$#" -lt 1 ]; then
	echo "Usage: $0 input_csv_file"
	exit 1;
fi

[[ `whoami` != "root" ]] && echo "You must be root to run the setup" && exit 1;


INPUT_FILE=$1
OSTYPE=`uname`
QUIET="-q"
PROGNAME=$(basename ${0})
user_id=`whoami`
DEFAULT_USER_SHELL="/bin/bash"

for USER in `awk -F, '{print $1}' $INPUT_FILE`
do

USER_ID=$USER
GECOS=`grep -w $USER_ID $INPUT_FILE | awk -F, '{print $7}'`
GROUP=`grep -w $USER_ID $INPUT_FILE | awk -F, '{print $4}'`
AUTH_KEY=`grep -w $USER_ID $INPUT_FILE | awk -F, '{print $2}'`
#echo "$USER_ID, $GECOS, $GROUP"

#################################################################################################################################

check_id () {
	id $USER_ID > /dev/null 2>&1; RC1=$?
	if [[ $RC1 -ne 0 ]]
	then 
		echo "Warning: User ID \"$USER_ID\" does not exists! Creating the ID" >> ./IDSetupLogs.txt
		ADD_IDS $USER_ID || { exit 1; }
	fi
}

prog_ind_dot ()
{
        printf "Please wait"
        while true
        do
                printf "."
        sleep 1
        done
}

GROUP_create () {
#	echo "inside group create"
	grep $QUIET $GROUP /etc/group; RC=$?
	if [[ $RC -ne 0 ]]
	then
		echo "Creating $GROUP group"
		if [[ "$OSTYPE" = AIX ]] 
		then
			/usr/bin/mkgroup $GROUP
			[ $? -eq 0 ] && echo "group \"$GROUP\" created succesfully" || echo "Error creating group \"$GROUP\"!" >> ./IDSetupLogs.txt
		else
			/usr/sbin/groupadd $GROUP
			[ $? -eq 0 ] && echo "group \"$GROUP\" created succesfully" || echo "Error creating group \"$GROUP\"!" >> ./IDSetupLogs.txt
		fi
	else
		echo "group \"$GROUP\" exists" >> ./IDSetupLogs.txt
	fi
}

ADD_IDS () {
#	echo "inside add_ids"
	GROUP_create
#	echo "Creating IDs"
	if [[ "$OSTYPE" = AIX ]]
	then
		/usr/bin/mkuser pGROUP=$GROUP registry=files SYSTEM=compat gecos="$GECOS" $USER_ID
		/usr/bin/pwdadm -c $USER_ID
	else
		/usr/sbin/useradd -g $GROUP -c "$GECOS" $USER_ID
	fi
	usermod -s $DEFAULT_USER_SHELL $USER_ID
}

PUT_KEYS () {
	printf "Deploying ssh keys..." >> ./IDSetupLogs.txt
	mkdir -p /home/$USER_ID/.ssh
	chmod 700 /home/$USER_ID/.ssh
	echo $AUTH_KEY > /home/$USER_ID/.ssh/authorized_keys
	cp /home/$USER_ID/.ssh/authorized_keys /home/$USER_ID/.ssh/authorized_keys2
	chown -R $USER_ID.$GROUP /home/$USER_ID
	chmod 600 /home/$USER_ID/.ssh/authorized_keys*
	[ $? -eq 0 ] && printf "Success\n" || printf "Failed\n"
}

configure () {
	printf "Setting correct Homedir and group membership..." >> ./IDSetupLogs.txt
	mkdir -p /home/$USER_ID >/dev/null 2>&1
	if [[ "$OSTYPE" = AIX ]]
	then
		/usr/bin/chuser home=/home/$USER_ID $USER_ID >/dev/null 2>&1
		/usr/bin/chuser pGROUP=$GROUP $USER_ID >/dev/null 2>&1
		[ $? -eq 0 ] && printf "Success\n" || printf "Failed\n"
	else
		/usr/sbin/usermod -d /home/$USER_ID $USER_ID >/dev/null 2>&1
		/usr/sbin/usermod -g $GROUP $USER_ID >/dev/null 2>&1
		[ $? -eq 0 ] && printf "Success\n" || printf "Failed\n"
	fi


	# Set Permissions:
	printf "Set Permissions of homedir/keys..." >> ./IDSetupLogs.txt
	chown -R $USER_ID.$GROUP /home/$USER_ID
	chmod 700 /home/$USER_ID
	[ $? -eq 0 ] && printf "Success\n" || printf "Failed\n"

	# Lock Down the IDs
	printf "Set Maxage to 90 for the IDs..."
	if [[ "$OSTYPE" = AIX ]]
	then
		chuser maxage=90 $USER_ID
		echo "$USER_ID:*" |chpasswd -ce
		chsec -f /etc/security/lastlog -s $USER_ID -a unsuccessful_login_count=0
		[ $? -eq 0 ] && printf "Success\n" || printf "Failed\n"
	else
		passwd -l $USER_ID >/dev/null 2>&1
		[ $? -eq 0 ] && printf "Success\n" || printf "Failed\n"
		printf "Set the ID $USER_ID to 90 days expiry..." >> ./IDSetupLogs.txt
		/usr/bin/chage -M 90 $USER_ID;
		[ $? -eq 0 ] && printf "Success\n" || printf "Failed\n"
		[[ -f /usr/bin/faillog ]] && ( /usr/bin/faillog -ru $USER_ID )
		[[ -f /sbin/pam_tally2 ]] && ( /sbin/pam_tally2 -r -u $USER_ID )
	fi
	# Setup public keys if AUTH_KEY is set
	[[ ! -z $AUTH_KEY ]] && PUT_KEYS $USER_ID || echo "SSH Publik key is not configured! Please deploy Manually" 
}

check_setup () {
	printf "================Validating Setup====================\n"
	printf "Checking /etc/passwd..."
	cat /etc/passwd|grep $USER_ID|grep $QUIET /home/$USER_ID && echo "$USER_ID homedir check PASSED" || echo "$USER_ID homedir check FAILED"

	printf "Checking /etc/group"
	id $USER_ID|grep $QUIET $GROUP && echo "$USER_ID group check PASSED" || echo "$USER_ID group check FAILED"

	printf "Checking ID Maxage..."
	if [[ $OSTYPE = AIX ]]
	then
		cat /etc/security/passwd|grep -p $USER_ID|grep -i password|grep $QUIET '*' && echo "$USER_ID passlock check PASSED" || echo "$USER_ID passlock check FAILED"
		lsuser -a maxage $USER_ID|grep $QUIET 90 && echo "$USER_ID maxage 90 check PASSED" || echo "$USER_ID maxage 90 check FAILED" 
	else
		cat /etc/shadow|grep $USER_ID|grep "!"|grep $QUIET 90 && echo "$USER_ID age check PASSED" || echo "$USER_ID age check FAILED"
	fi
	
	printf "================End of Validation===================\n"
}

#set -x
# MAIN 
echo "=================Setting up ID \"$USER_ID\"=================="
check_id $USER_ID
configure $USER_ID
check_setup $USER_ID
echo "=================End of setup for ID \"$USER_ID\"=================="
done
