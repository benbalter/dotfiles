#!/bin/sh

npm install prey -g

if sudo prey config check; then
else
  sudo prey config account setup
  sudo prey config plugins enable control-panel
fi
