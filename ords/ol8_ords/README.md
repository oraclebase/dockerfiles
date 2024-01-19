# Oracle REST Data Services (ORDS) on Docker

The following article provides a description of this Dockerfile.

[Docker : Oracle REST Data Services (ORDS) on Docker](https://oracle-base.com/articles/linux/docker-oracle-rest-data-services-ords-on-docker)

Directory contents when software is included.

```
$ tree
.
├── Dockerfile
├── README.md
├── scripts
│   ├── healthcheck.sh
│   ├── install_os_packages.sh
│   ├── ords_software_installation.sh
│   ├── server.xml
│   └── start.sh
└── software
    ├── apache-tomcat-9.0.78.tar.gz
    ├── apex_23.2_en.zip
    ├── graalvm-jdk-17_linux-x64_bin.tar.gz
    ├── ords-latest.zip
    ├── put_software_here.txt
    └── sqlcl-latest.zip

$
```

If you are using an external host volume for persistent storage, the build expects it to owned by a group with the group ID of 1042. This is described here.

[Docker : Host File System Permissions for Container Persistent Host Volumes](https://oracle-base.com/articles/linux/docker-host-file-system-permissions-for-container-persistent-host-volumes)
