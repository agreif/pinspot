#!/bin/sh

BASE_DIR=base
ACTIONS_DIR=actions
FILES_DIR=files
SCRIPTS_DIR=scripts
FACTS_DIR=facts
REMOTE_DIR=.pinspot
REMOTE_USER=$LOGNAME
NEEDS_SUDO=0
NEEDS_SUDO_PW=0

while getopts "u:m:MsSq" opt; do
    case $opt in
	u) REMOTE_USER="$OPTARG";;
	s) NEEDS_SUDO=1;;
	S) NEEDS_SUDO_PW=1;;
    esac
done
shift $((OPTIND-1))

HOST_PATHS="$@"

if test -z "$HOST_PATHS"; then
    echo "host_paths missing"
    exit 1
fi

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

TMP_TAR=tmp.tar
TMP_SH=tmp.sh

for host_path in $HOST_PATHS; do
    host_dir=`echo $host_path | sed 's|/$||' | awk -F/ '{print $NF}'`
    host_port=`echo $host_dir | sed 's/\([^_]*\)_.*$/\1/'`
    host=`echo $host_port | awk -F/ '{print $NF}' | awk -F: '{print $1}'`
    port=`echo $host_port | awk -F/ '{print $NF}' | awk -F: '{print $2}'`
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
echo "flatten actions..."
cd actions
find . -name '.DS_Store' -exec rm {} \\;
find . -name '._*' -exec rm {} \\;
for path in \`find . -type f\`; do
    path=\`echo \$path | sed 's|^\./||'\`
    echo \$path | grep -q '/'
    if test \$? -eq 0; then
        dir_name=\`dirname \$path | sed 's#/#-#g' | sed 's#_#-#g'\`
        file_name=\`basename \$path\`
        new_file_name="\$dir_name-\$file_name"
        mv \$path \$new_file_name
    fi
done
# remove remaining empty dirs
for d in *; do
    if test -d \$d; then
        rm -rf \$d
    fi
done
cd ..

echo "fix file flags..."
chmod u=rx,go-rwx $SCRIPTS_DIR/* $FACTS_DIR/*
echo "export facts..."
for fact in \`ls $FACTS_DIR\`; do
    echo "  \$fact"
    var="\`$FACTS_DIR/\$fact\`"
    result=\$?
    if test \$result -ne 0; then echo "ERROR exitcode: \$result"; exit 1; fi
    echo "    \$var"
    export \$var
done

echo "exec actions..."
for action_file in \`ls $ACTIONS_DIR\`; do
    script=\`echo \$action_file | cut -d _ -f 2\`
    echo
    echo "\$action_file"
    PINSPOT_ACTION_FILE=\`pwd\`/$ACTIONS_DIR/\$action_file \
        PINSPOT_FILES_DIR=\`pwd\`/$FILES_DIR \
        PINSPOT_REMOTE_USER=$REMOTE_USER \
        \`pwd\`/$SCRIPTS_DIR/\$script
    result=\$?
    if test \$result -ne 0; then echo "ERROR exitcode: \$result"; exit 1; fi
done
EOF

    echo "pack tmp script ..."
    tar -cf $TMP_TAR $TMP_SH
    if test $? -ne 0; then exit 1; fi

    echo "pack base ..."
    tar -rf $TMP_TAR --exclude actions -C base .
    if test $? -ne 0; then exit 1; fi

    echo "pack server ..."
    tar -rLf $TMP_TAR -C $host_path .
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
