#!/bin/sh

BASE_DIR=base
ACTIONS_DIR=actions
FILES_DIR=files
MONITORS_DIR=monitors
SCRIPTS_DIR=scripts
FACTS_DIR=facts
REMOTE_DIR=.pinspot
REMOTE_USER=$LOGNAME
ALL_MONITORS=0
MONITOR_CMDS=''
NEEDS_SUDO=0
NEEDS_SUDO_PW=0
QUIET=0

while getopts "u:m:MsSq" opt; do
    case $opt in
	u) REMOTE_USER="$OPTARG";;
        m) MONITOR_CMDS="$OPTARG";;
	M) ALL_MONITORS=1;;
	s) NEEDS_SUDO=1;;
	S) NEEDS_SUDO_PW=1;;
	q) QUIET=1;;
    esac
done
shift $((OPTIND-1))

HOST_PATHS="$@"

if test -z "$HOST_PATHS"; then
    echo "host_paths missing"
    exit 1
fi

if test $ALL_MONITORS -eq 1; then
    MONITOR_CMDS=`ls $BASE_DIR/$MONITORS_DIR`
fi

MONITOR_CMDS=`echo "$MONITOR_CMDS" | sed 's/,/ /g'`

PASSWORD=''
if test $NEEDS_SUDO_PW -eq 1; then
    read -s -p "Please enter your sudo password: " PASSWORD
    NEEDS_SUDO=1
fi

SUDO_CMD=""
if test $NEEDS_SUDO_PW -eq 1; then
    SUDO_CMD="echo '$PASSWORD' | sudo -S -p ''"
elif test $NEEDS_SUDO -eq 1; then
    SUDO_CMD="sudo"
fi

echo "HOST_PATHS: $HOST_PATHS"
echo "MONITOR_CMDS: $MONITOR_CMDS"

TMP_TAR=tmp.tar
TMP_SH=tmp.sh

for host_path in $HOST_PATHS; do
    host_dir=`echo $host_path | sed 's|/$||' | awk -F/ '{print $NF}'`
    host=`echo $host_dir | awk -F/ '{print $NF}' | awk -F: '{print $1}'`
    port=`echo $host_dir | awk -F/ '{print $NF}' | awk -F: '{print $2}'`
    echo "host: $host   port: $port"
    if test -z "$port"; then
	port=22
    fi
    echo "host: $host   port: $port"

    echo "cleanup..."
    ssh $host -p $port -l $REMOTE_USER -t \
	"if test -d $REMOTE_DIR; then $SUDO_CMD rm -rf $REMOTE_DIR; fi" \
	"&& mkdir -p $REMOTE_DIR" \
	"&& chmod 700 $REMOTE_DIR" 2> /dev/null
    if test $? -ne 0; then exit 1; fi

    echo "create action script..."
    cat > $TMP_SH <<EOF
echo "fix file flags......"
chmod u=rx,go-rwx $SCRIPTS_DIR/* $MONITORS_DIR/* $FACTS_DIR/*
echo "export facts..."
for fact in \`ls $FACTS_DIR\`; do
    echo "  \$fact"
    var="\`$FACTS_DIR/\$fact\`"
    result=\$?
    if test \$result -ne 0; then echo "ERROR exitcode: \$result"; exit 1; fi
    echo "    \$var"
    export \$var
done

if test -z "$MONITOR_CMDS"; then
    echo "exec actions..."
    for action_file in \`ls $ACTIONS_DIR\`; do
        script=\`echo \$action_file | cut -d _ -f 2\`
        echo
        echo "\$action_file"
        PINSPOT_ACTION_FILE=\`pwd\`/$ACTIONS_DIR/\$action_file \
            PINSPOT_FILES_DIR=\`pwd\`/$FILES_DIR \
            \`pwd\`/$SCRIPTS_DIR/\$script
        result=\$?
        if test \$result -ne 0; then echo "ERROR exitcode: \$result"; exit 1; fi
    done
else
    echo "run monitors..."
    for monitor_cmd in $MONITOR_CMDS; do
        echo
        echo "\$monitor_cmd"
        \`pwd\`/$MONITORS_DIR/\$monitor_cmd
        result=\$?
        if test \$result -ne 0; then echo "ERROR exitcode: \$result"; exit 1; fi
    done
fi
EOF

    echo "pack..."
    tar -cf $TMP_TAR -C . $TMP_SH -C base . -C ../$host_path .
    if test $? -ne 0; then exit 1; fi

    echo "transfer..."
    scp -P $port -q $TMP_TAR $REMOTE_USER@$host:$REMOTE_DIR
    if test $? -ne 0; then exit 1; fi

    ssh $host -p $port -l $REMOTE_USER -t \
    	"cd $REMOTE_DIR" \
    	"&& echo \"unpack...\"" \
    	"&& tar -xf $TMP_TAR" \
    	"&& $SUDO_CMD sh $TMP_SH" 2> /dev/null

    echo "cleanup..."
    ssh $host -p $port -l $REMOTE_USER -t "if test -d $REMOTE_DIR; then $SUDO_CMD rm -rf $REMOTE_DIR; fi" 2> /dev/null
    if test $? -ne 0; then exit 1; fi

    rm $TMP_TAR
    rm $TMP_SH
done
