# **bouncemod v1.0.0**

Bouncemod is a tool for easily modifying any remote servers. You can either pass ssh credentials in as run arguments or have it search the current user's Map.conf file.

Any number of actions can be selected to be run on each machine.

## Usage

**Use credentials from Map.conf**

`bouncemod`

**Pass credentials as run arguments**

`bouncemod [user@password] [ip]`

Example:

`bouncemod root@spider 1.2.3.4`

Any number of ssh credentials can be passed in

`bouncemod root@three 1.2.3.4 root@remote 5.6.7.8 root@machines 9.10.11.12`

## Features

### Access files

- Upload
- Download
- Delete

### Run files

- Binary **_\*Only programs able to be run by using `launch()`_**
