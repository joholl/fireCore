#!/bin/sh

# change password of user 'tc' to 'piCore'
sh -c "echo 'tc:piCore' | chpasswd"
