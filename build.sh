#!/bin/bash
#
# Run this to build, tag and create fat-manifest for your images


set -e

if [[ -f build.config ]]; then
  # spellcheck source=build.config
  source ./build.config
else
  echo "ERROR: ./build.config not found."
  exit 1
fi

# Fail on empty params
if [[ -z "${REGISTRY}" ]]; then
    REPO="${REPOSITORY}"
elif [[ -n "${REPOSITORY}" ]]; then
    REPO="${REGISTRY}/${REPOSITORY}"
elif [[ -n "${REGISTRY}" ]]; then
    REPO="${REGISTRY}"
else
  echo "ERROR: Please set at least REGISTRY or REPOSITORY in build.conf."
  exit 1
fi

if [[ -z "${REPO}" || -z "${IMAGE_NAME}" || -z "${TARGET_ARCHES}" ]]; then
  echo "ERROR: Please set build parameters." 1>&2
  exit 1
fi

if [[ -z "$(DOCKER_CLI_PATH)" ]]; then
    DOCKER_CLI_PATH="$(command -v docker)"
fi

echo "Using $(DOCKER_CLI_PATH) as Docker."

# Determine OS and Arch.
build_os="$(uname -s | tr '[:upper:]' '[:lower:]')"
build_uname_arch="$(uname -m | tr '[:upper:]' '[:lower:]')"

case "${build_uname_arch}" in
  x86_64  ) build_arch=amd64 ;;
  aarch64 ) build_arch=arm ;;
  arm*    ) build_arch=arm ;;
  *)
    echo "ERROR: Sorry, unsuppoted architecture ${build_uname_arch};"
    exit 1
    ;;
esac

if [[ ! $(DOCKER_CLI_EXPERIMENTAL="enabled" docker manifest --help) ]] || [[ "$(DOCKER_CLI_EXPERIMENTAL="enabled" docker manifest --help | grep -c "docker manifest is only supported on a Docker cli with experimental cli features enabled")" -eq 1 ]]; then
  echo "ERROR: Missing Docker CLI with manifest command \(command tried: ${DOCKER_COMMAND}\)"
  echo "ERROR: Maybe you deen a more recent Docker."
  exit 1
fi

if [[ -z ${IMAGE_VERSION} ]]; then
  IMAGE_VERSION="latest"
fi

if [[ -z "${BASE_IMAGE}" ]]; then
    echo "INFO: No BASE_IMAGE specified in build.conf, defaulting to alpine:edge"
    BASE_IMAGE="alpine:edge"
fi

for docker_arch in ${TARGET_ARCHES}; do
  case ${docker_arch} in
    amd64       ) qemu_arch="x86_64" ;;
    arm32v[5-7] ) qemu_arch="arm" ;;
    arm64v8     ) qemu_arch="aarch64" ;;
    *)
      echo ERROR: Unknown target arch.
      exit 1
  esac
  cp Dockerfile.cross "Dockerfile.${docker_arch}"
  if [[ "${build_os}" == "darwin" ]]; then
      sed -i '' "s|__BASEIMAGE_ARCH__|${docker_arch}|g" "Dockerfile.${docker_arch}"
      sed -i '' "s|__BASEIMAGE_NAME__|${BASE_IMAGE}|g" "Dockerfile.${docker_arch}"
      sed -i '' "s|__QEMU_ARCH__|${qemu_arch}|g" "Dockerfile.${docker_arch}"
  else
      sed -i "s|__BASEIMAGE_ARCH__|${docker_arch}|g" "Dockerfile.${docker_arch}"
      sed -i "s|__BASEIMAGE_NAME__|${BASE_IMAGE}|g" "Dockerfile.${docker_arch}"
      sed -i "s|__QEMU_ARCH__|${qemu_arch}|g" "Dockerfile.${docker_arch}"
  fi
  if [[ "${docker_arch}" == "amd64" || "${build_os}" == "darwin" ]]; then
    sed -i "/__CROSS_/d" "Dockerfile.${docker_arch}"
  else
    sed -i "s/__CROSS_//g" "Dockerfile.${docker_arch}"
  fi
  DOCKER_CLI_EXPERIMENTAL="enabled" docker build -f "Dockerfile.${docker_arch}" -t "${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}" .
  DOCKER_CLI_EXPERIMENTAL="enabled" docker push "${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}"
  arch_images="${arch_images} ${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}"
  rm "Dockerfile.${docker_arch}"
done

echo "INFO: Creating fat manifest for ${REPO}/${IMAGE_NAME}:${IMAGE_VERSION}"
echo "INFO: with subimages: ${arch_images}"

if [[ -z "${REGISTRY}" ]]; then
    local_manifest_dir_name="docker.io_${REPO}_${IMAGE_NAME}-${IMAGE_VERSION}"
else
    local_manifest_dir_name="${REPO}_${IMAGE_NAME}-${IMAGE_VERSION}"
fi

if [ -d "${HOME}/.docker/manifests/${local_manifest_dir_name}" ]; then
      rm -rf "${HOME}/.docker/manifests/${local_manifest_dir_name}"
fi
DOCKER_CLI_EXPERIMENTAL="enabled" docker manifest create --amend "${REPO}/${IMAGE_NAME}:${IMAGE_VERSION}" "${arch_images}"
for docker_arch in ${TARGET_ARCHES}; do
  case ${docker_arch} in
    amd64       ) annotate_flags="" ;;
    arm32v[5-7] ) annotate_flags="--os linux --arch arm" ;;
    arm64v8     ) annotate_flags="--os linux --arch arm64 --variant armv8" ;;
  esac
  echo "INFO: Annotating arch: ${docker_arch} with \"${annotate_flags}\""
  DOCKER_CLI_EXPERIMENTAL="enabled" docker manifest annotate "${REPO}/${IMAGE_NAME}:${IMAGE_VERSION}" "${REPO}/${IMAGE_NAME}:${docker_arch}-${IMAGE_VERSION}" "${annotate_flags}"
done
echo "INFO: Pushing ${REPO}/${IMAGE_NAME}:${IMAGE_VERSION}"
DOCKER_CLI_EXPERIMENTAL="enabled" docker manifest push "${REPO}/${IMAGE_NAME}:${IMAGE_VERSION}"
