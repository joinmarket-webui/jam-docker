#!/bin/bash
set -e

# for more info see: https://www.unix.com/man-page/Linux/8/savelog/
savelog -t -p -l -n -c 5 /var/log/jam/jmwalletd_stdout.log
