#!/usr/bin/env bash

checkbinary(){
if command -v "$1"; then
    echo "INFO: ${1}: $(command -v "$1")"
    true
else
    echo "ERROR: $1 not installed, please install it" 1>&2
    false
fi
}
