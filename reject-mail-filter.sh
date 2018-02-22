#!/bin/sh

message="
The addresses amc@*.berkeley.edu are obsolete.
For Adam M. Costello's current email address, see
http://www.cs.berkeley.edu/~amc/addresses.var#email
"

echo "$message" >&2
read from sender_address rest

if [ "$from" = From ]; then
  sendmail=sendmail

  for dir in /usr/lib /usr/bin /usr/sbin /bin /sbin; do
    [ ! -x $dir/sendmail ] || sendmail=$dir/sendmail
  done

  case "$sender_address" in
    help@[Ee][Ee][Cc][Ss].* | help@[Cc][Ss].* | \
    [Mm][Aa][Ii][Ll][Ee][Rr]-[Dd][Aa][Ee][Mm][Oo][Nn] | '<>' ) exit ;;
    *@* ) $sendmail -f '<>' "$sender_address" << EOF
From: "Adam M. Costello":;
To: $sender_address
Subject: Adam M. Costello's new address

The addresses amc@*.berkeley.edu are obsolete.
For Adam M. Costello's current email address, see
http://www.cs.berkeley.edu/~amc/addresses.var#email
EOF
    ;;
  esac
fi

exit 1
