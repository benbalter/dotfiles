#!/bin/sh

npm install prey -g

sudo prey config account setup
sudo prey config plugins enable control-panel
sudo prey config check
