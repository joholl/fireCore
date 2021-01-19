#!/bin/bash

set -e

sudo umount mnt/* || true
rm -rf mnt piCore* tce.cpio
sudo rm -rf /tftpboot/*
