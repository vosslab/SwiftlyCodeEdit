#!/bin/sh

ps -ef | grep CodeEdit \
  | grep -v grep | grep -v sed | cut -c-200
echo ""
uptime
