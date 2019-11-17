# docker-multiarch-builder
Simple framework for building multi-arch images.

## Preparing your build machine

Install the following packages using your package manager:
 - docker (required, should be recent enough to support the `manifest` command, so at least 18.02.0-ce)
 - qemu-user-static (recommended, but the script will download the binaries from GitHub for you if they are missing) 

Run following commands on a host only once:
```bash
$ ./run-once.sh
```

This will check dependencies and register necessary binfmt_misc handlers.

Running `./run-once.sh` multiple times should not cause any harm.

## Initializing your project

When you want to create your Docker project, run this first:

```bash
$ mkdir /usr/src/docker-project-name
$ ./init-repo.sh /usr/src/docker-project-name
```

This will download static qemu binaries into your project `qemu/` directory (if they are not installed already), prepare a stub of your Dockerfile.cross, and provide a local copy of your `build.sh` and `build.config` that you should use to build your images.

Runnig `./init-repo.sh` multiple times on the same project should not cause any harm and it can be used to "install" a newer `./build.sh`.

> WARNING: Currently if the build.sh in the project differs form the current build.sh, the project's build.sh will be renamed and a new build.sh is installed.

## Configuring build process

> WARNING: The structure of build.config changed. "REPO" is deprecated, but still working.

Build configuration is in `build.config` in your project directory. It has number of parameters:
- `IMAGE_NAME` (required) - Image name that you would like to build. Probably your project name.
- `TARGET_ARCHES` (required) - List of target architectures you would like to build.
- `REGISTRY` (optional/required) - The address of the registry to use. Assuming `docker.io` if empty. You should already be logged in and have write access to this registry. You should at least specify either `REGISTRY` or `REPOSITORY` or both.
- `REPOSITORY` (optional/required) - Name of your repository ("sub-directory"). Assuming `/` if empty. You should at least specify either `REGISTRY` or `REPOSITORY` or both.
- `IMAGE_VERSION` (optional) - Leave empty for "latest"
- `DOCKER_CLI_PATH` (optional) - Path where docker CLI that supports manifest command is. You can leave it empty if you added it to path (or want to use the already installed `docker` command).
- `BASE_IMAGE` (optional) - The name of the base image to use. Defaults to `alpine:edge` if not specified.

Naturally, you should also edit your `Dockerfile.cross` and put meaningful build instructions. Just make sure `__CROSS_COPY` is placed before any `RUN`.

Keep `__BASEIMAGE_ARCH__`, `__BASEIMAGE_NAME__`, `__CROSS_COPY` and `__QEMU_ARCH__` placeholder, as they are used to generate temporary Dockerfiles for each of the build architectures.

To actually build, tag images and push all of them + fat manifest to repository:
```
cd /usr/src/docker-project-name
./build.sh
```
(NOTE: You need to be logged in to the repository)
