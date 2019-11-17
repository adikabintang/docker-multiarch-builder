#!/bin/bash
#
# Run this to prepare and initialize new Docker image build repo
# -----

set -e

# shellcheck source=config.sh
source config.sh

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d ${1} && ! -w ${1} ]]; then
  echo "ERROR: Please supply a valid, writeable directory path."
  echo "ERROR: for example:"
  echo "ERROR: ${0} /usr/src/docker-something"
  exit 1
fi

DEST="$(cd "${1}" && pwd)"

echo I"NFO: Setting up ${DEST} from ${CWD}"
if [[ $(uname -m) != "x86_64" ]]; then
  echo "ERROR: This script is really used for building Docker images on x86_64 machines."
  exit 1
fi

if [[ $(uname -s) != "Darwin" ]]; then
  mkdir -p "${DEST}/qemu" "${CWD}/qemu"
  for target_arch in ${BUILD_ARCHS}; do
    if [[ "$(command -v "qemu-${target_arch}-static")" ]]; then
        echo "INFO: qemu-${target_arch}-static installed, using it"
        cp "$(command -v "qemu-${target_arch}-static")" "${DEST}/qemu"
    else
        echo "INFO: qemu-${target_arch}-static no installed, downloading qemu-${target_arch}-static version ${QEMU_VERSION}"
        [[ -f "${CWD}/qemu/x86_64_qemu-${target_arch}-static.tar.gz" ]] || wget -N -P "${CWD}/qemu" "https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VERSION}/x86_64_qemu-${target_arch}-static.tar.gz"
        tar -xvf "${CWD}/qemu/x86_64_qemu-${target_arch}-static.tar.gz" -C "${DEST}/qemu"
    fi
  done
else
  echo INFO: Running on Mac, skipping Qemu build.
fi

if [[ ! -f "${DEST}/Dockerfile.cross" ]]; then
    cat << 'EOF' > "${DEST}/Dockerfile.cross"
FROM __BASEIMAGE_ARCH__/__BASEIMAGE_NAME__

__CROSS_COPY qemu/qemu-__QEMU_ARCH__-static /usr/bin/
EOF
else
  echo "WARN: Dockerfile.cross already exists."
  echo "WARN: Differences:"
  diff -y -W250 "${DEST}/Dockerfile.cross" <( cat << 'EOF'
FROM __BASEIMAGE_ARCH__/__BASEIMAGE_NAME__

__CROSS_COPY qemu/qemu-__QEMU_ARCH__-static /usr/bin/
EOF
) | expand | grep -E -C3 '^.{123} [|<>]( |$)'

fi

if [[ ! -f "${DEST}/build.sh" ]]; then
  cp "${CWD}/build.sh" "${DEST}"
else
  echo "WARN: build.sh already exists."
  if [[ "$(md5sum "${CWD}/build.sh" | cut -d ' ' -f 1)" == "$(md5sum "${DEST}/build.sh" | cut -d ' ' -f 1)" ]]; then
    echo "WARN: and it seems to be identical"
  else
    echo "WARN: and it differs from the current one"
    echo "WARN: Differences:"
    diff -y -W250 "${CWD}/build.sh" "${DEST}/build.sh" | expand | grep -E -C3 '^.{123} [|<>]( |$)'
    timestamp="$(date +%s)"
    echo "WARN: The old build.sh will be renamed to build.sh.${timestamp} and a new one will be installed"
    mv "${DEST}/build.sh" "${DEST}/build.sh.${timestamp}"
    cp "${CWD}/build.sh" "${DEST}"
  fi
fi

if [[ ! -f "${DEST}/build.config" ]]; then
  cp "${CWD}/build.config" "${DEST}"
else
  echo "WARN: build.config already exists."
  echo "WARN: Differences:"
  diff -y -W250 "${CWD}/build.config" "${DEST}" | expand | grep -E -C3 '^.{123} [|<>]( |$)'
fi

if [[ -f "${DEST}/.gitignore" ]]; then
    [[ $(grep -c -F "build.sh" "${DEST}/.gitignore") -eq 0 ]] && echo "build.sh" >> "${DEST}/.gitignore"
    [[ $(grep -c -F 'build.sh.*' "${DEST}/.gitignore") -eq 0 ]] && echo "build.sh.*" >> "${DEST}/.gitignore"
    [[ $(grep -c -F "build.config" "${DEST}/.gitignore") -eq 0 ]] && echo "build.config" >> "${DEST}/.gitignore"
else
{
    echo "build.sh"
    echo "build.sh.*"
    echo "build.config"
} >> "${DEST}/.gitignore"
fi