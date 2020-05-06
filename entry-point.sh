#!/bin/bash

export PATH="$HOME/.rbenv/bin:$PATH"

eval "$(rbenv init -)"

cd $(dirname $0)

ruby ./get_indoor_air_condition.rb 2>> /tmp/error_air.log
