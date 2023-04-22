# OpenCV build and packaging script for Debian/Ubuntu

Working with up to date version of OpenCV when using Debian or Ubuntu, both commonly used as basis for (docker) containers or VMs/cloud instances, is a bit tricky. This script provides an easy to use build instruction to create a (system-wide) `.deb` package suitable for the OS it was build with.

## Features

- all CUDA features are enabled
- only non-free features are deactivated (`-DOPENCV_ENABLE_NONFREE=OFF`)
- GAPI support (C++ and Python) is enabled

## Instructions

1. clone repository
2. execute `./build_package.sh`
3. install `./build/opencv-cuda_x.x.x-x_all.deb` (`# dpkig -i ./filename`)
4. remove build folder (you may want to keep a backup of the `.deb` file built)



## Acknowledgements

The packaging and build scripts are based on the work of the debian science team ([https://salsa.debian.org/science-team/opencv](https://salsa.debian.org/science-team/opencv)).


## Other notes

- tested with `x86_64`