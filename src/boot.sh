#!/bin/sh

# change password of user 'tc' to 'piCore'
sh -c "echo 'tc:piCore' | chpasswd"

# install python packages using wheel
python3 -m pip install /tmp/wheel/optional/*

# run server
cd /tmp/app && python3 server.py && cd