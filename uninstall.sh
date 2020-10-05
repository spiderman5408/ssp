#!/bin/bash

set -x

systemctl stop ssp
systemctl disable ssp

rm -rf /usr/bin/ssp /etc/systemd/system/ssp.service /etc/systemd/system/ssp@.service /etc/ssp /var/log/ssp

set -

echo "Success"
