# Oracle Database on Docker

The following article provides a description of this Dockerfile.

[Docker : Oracle Database on Docker](https://oracle-base.com/articles/linux/docker-oracle-database-on-docker)

Directory contents when software is included.

```
$ tree
.
├── Dockerfile
├── README.md
├── scripts
│   ├── healthcheck.sh
│   └── start.sh
└── software
    ├── apex_21.2_en.zip
    ├── linuxx64_12201_database.zip
    └── put_software_here.txt

$
```

If you are using an external host volume for persistent storage, the build expects it to owned by a group with the group ID of 1042. This is described here.

[Docker : Host File System Permissions for Container Persistent Host Volumes](https://oracle-base.com/articles/linux/docker-host-file-system-permissions-for-container-persistent-host-volumes)
