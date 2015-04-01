# pinspot

**Work in Progress ... the primary aim is to configure my OpenBSD boxes**

### What I wanted to avoid

I always wanted a simple configuration management too for my unix/linux boxes that ...

* needs no dependencies like ruby, python

* needs no bloated DSL or XML configuration files

* needs no open ports for master/agent stuff

### What I only need

Back to the roots, all I want to use to configure my systems is:

* SSH

* shell scripts

* push-based configuration

### Folder structure

```Shell
pinspot
├── pinspot.sh
├── base
│   ├── facts
│   │   ├── osName
│   │   └── osRelease
│   ├── files
│   │   ├── bar.txt
│   │   └── foo.txt
│   ├── monitors
│   │   ├── load
│   │   └── uptime
│   └── scripts
│       ├── addAuthorizedKey
│       ├── addFileLines
│       ├── createDir
│       ├── createFile
│       ├── createGroup
│       ├── createUser
│       ├── execScript
│       ├── includeSudoersDir
│       ├── installPackages
│       ├── sshKeygen
│       ├── sshdAllowX11Forwarding
│       └── sshdDisableRootLogin
└── servers
    ├── example.com
    │   ├── actions
    │   │   ├── 010_addFileLines_root_profile
    │   │   ├── 020_createFile_root_kshrc
    │   │   ├── 030_createDir_tmp_foo
    │   │   └── 100_sshdDisableRootLogin
    │   ├── files
    │   │   └── foo.txt
    │   └── scripts
    └── example.com:2222
        ├── actions
        ├── files
        └── scripts
```

`/pinspot.sh` - the main script that runs the configuration of the servers

`/base/` - contains all global stuff that is needed to configure the servers

`/base/facts/` - small scripts that collect information from the remote server that can be used in the scripts

`/base/files/` - files or folders that can be used for all servers

`/base/monitors/` - small scripts that check something on the remote server side

`/base/scripts/` - small scripts that do the real job on the remote side. They get the server-specific action file, that contains the params

`/servers/` - server-specific configurations

`/servers/<hostname>/` - configuration files for a specific server. `hostname` can be... 1. domain name or 2. IP address and can have the ssh port as a suffix after the colon

`/servers/<hostname>/actions/` - contains the actions to be taken on the specific server

`/servers/<hostname>/files/` - like `/base/files/` but specific to this server

`/servers/<hostname>/scripts/` - like `/base/scripts/` but specific to this server

