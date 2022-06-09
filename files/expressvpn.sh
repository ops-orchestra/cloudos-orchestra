#!/usr/bin/expect

set EXPRESSVPN_CODE [lindex $argv 0]

set timeout 10
spawn sudo expressvpn activate
expect "Enter activation code:\r"
send "${EXPRESSVPN_CODE}\r"
expect "*identifiable information. (Y/n)\r"
send "no\r"