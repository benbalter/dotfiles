#!/bin/sh

npm install prey -g

if sudo prey config check; then
  true
else
  sudo prey config account setup
  sudo prey config plugins enable control-panel
fi
