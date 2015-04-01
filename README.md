# pinspot

**Work in Progress ... the primary aim is to configure my OpenBSD boxes**

### I wanted to ...

* avoid dependencies like ruby, python

* avoid bloated DSL or XML configuration files

* avoid open ports for master/agent communication

### I needed ...

* only SSH

* only shell scripts

### Benefits

* push-based configuration

* sudo-able on the remote side

* see the the actions and its execution order at a glance

* specify the servers that need to be configured with shell filename globbing

### Command Line Usage

```Shell
Synopsys:
sh pinspot.sh [options] server-dirs

options:
    -u USER   - The ssh login name on the remote server.
                If not given takes the current user.
    -s        - Use sudo for config script executions.
                If password is needed, then you may be asked many times on the fly.
    -S        - Ask sudo password before configureing the hosts
                and use use the given sudo password for all given servers.
                SECURITY WARNING: password is visible with 'ps aux'
    -m        - List of monitor scripts to execute. Comma-separated of more than one.
                If given, configuration scripts are not run.
    -M        - Run all monitor scripts.
                If given, configuration scripts are not run.
```

Some examples:

On a completely fresh system with root login and public Key authorization (first pinspot run shold disable password authentication)

```Shell
$ sh pinspot.sh -u root servers/example.com
```

Configuration run with admin user who has NOPASSWD in sudoers:

```Shell
$ sh pinspot.sh -u joeadmin -s servers/example.com
```

Configuration run with admin user who has has to type in sudo password:

```Shell
$ sh pinspot.sh -u joeadmin -S servers/example.com
Please enter your sudo password:
```

In the case the logged in user is the admin (the -u can be left off)
and needs no sudo password

```Shell
$ sh pinspot.sh -s servers/example.com
```

Configure all servers with example.com domain:

```Shell
$ sh pinspot.sh -s servers/*.example.com
```

Configure all localhost servers:

```Shell
$ sh pinspot.sh -s servers/localhost*
```



### Folder structure

```Shell
pinspot
├── pinspot.sh
├── base
│   ├── facts
│   │   ├── osName
│   │   └── osRelease
│   ├── files
│   │   ├── bar.txt
│   │   └── foo.txt
│   ├── monitors
│   │   ├── load
│   │   └── uptime
│   └── scripts
│       ├── addAuthorizedKey
│       ├── addFileLines
│       ├── createDir
│       ├── createFile
│       ├── createGroup
│       ├── createUser
│       ├── execScript
│       ├── includeSudoersDir
│       ├── installPackages
│       ├── sshKeygen
│       ├── sshdAllowX11Forwarding
│       └── sshdDisableRootLogin
└── servers
    ├── example.com
    │   ├── actions
    │   │   ├── 010_addFileLines_root_profile
    │   │   ├── 020_createFile_root_kshrc
    │   │   ├── 030_createDir_tmp_foo
    │   │   └── 100_sshdDisableRootLogin
    │   ├── files
    │   │   └── foo.txt
    │   └── scripts
    └── example.com:2222
        ├── actions
        ├── files
        └── scripts
```

##### `/pinspot.sh`

The main script that runs the configuration of the servers.

##### `/base/`

Contains all *global* stuff that is needed to configure the servers.

##### `/base/facts/`

Small scripts that collect information from the remote server that can be used in the configuration scripts.
In order to do this all, fact scripts must
output only one line to the stdout so that the shell can export as environment variables.

`SOMEFACT=somevalue`

##### `/base/files/`

Files or folders that can be used on all servers.

##### `/base/monitors/`

Small scripts that check something on the remote server side. This is still an experimental feature.

##### `/base/scripts/`

Small *idempotent* scripts that do the real job on the remote side.
Idempotent means, that they must not generate negative effects if called many times.
They get the server-specific action file as an argument, that contains the specific params.
Execution happens with the following envirnment variables:

```Shell
PINSPOT_ACTION_FILE=<path-to-action-file> \
PINSPOT_FILES_DIR=<path-to-files-dir> \
FACTX=valueX \
FACTY=valueY \
FACTZ=valueZ \
theScriptToExecute
```

##### `/servers/`

Server-specific configurations.

##### `/servers/<hostname>/`

Configuration files for a specific server.
`hostname` can be

* domain name

* IP address

* or comethings that the `ssh` tool accepts as the remote server

and can have the ssh port as a suffix after the colon.
So if you have a local VM guest that you access with
`ssh -p 2222 localhost` then the foldername would be `/localhost:2222`.
You can also use symlinks if multiple servers need the same configuration:

```Shell
pinspot
└── servers
    ├── example.com/
    │   ├── actions
    │   ├── files
    │   └── scripts
    ├── db.example.com -> example.com/
    ├── www.example.com -> example.com/
    │
    ├── local_openbsd_vms/
    │   ├── actions
    │   ├── files
    │   └── scripts
    ├── localhost:2222 -> local_openbsd_vms/
    ├── localhost:2223 -> local_openbsd_vms/
    ├── localhost:2224 -> local_openbsd_vms/
```

##### `/servers/<hostname>/actions/`

Contains the actions to be taken on the specific server.
Action file names must have the following convention:

`<sortIndex>_<scriptName>_<comment>`

* the `sortIndex` (required) is used to determine the order of the actions

* the `scriptName` (required) corresponds with the script file name in  `/base/scripts/`. They *must* match.

* the `comment` (optional) is only informational. If not needed then that "_" is also optional.

##### `/servers/<hostname>/files/`

Like `/base/files/` but specific to this server.

##### `/servers/<hostname>/scripts/`

Like `/base/scripts/` but specific to this server.

### Why the funny name?

Why not? Sounds funny and caught me at the first thaught :)

