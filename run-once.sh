#!/bin/bash
#
# Run this script once on your build hosts

set -e

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=utils.sh
source "${CWD}"/utils.sh

if ! checkbinary docker; then
    exit 1
fi

if ! checkbinary qemu-arm-static || ! checkbinary qemu-x86_64-static; then
    echo "INFO: it looks like qemu-user-static is not installed, you should really install it if it is possible"
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "INFO: Registering handlers - requires sudo!"
  sudo docker run --rm --privileged multiarch/qemu-user-static:register
fi
