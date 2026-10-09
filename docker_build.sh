#!/bin/bash
#
# Builds the OpenCV .deb inside Docker and writes it to ./output/<variant>/

set -euo pipefail

usage() {
	echo "Usage: $0 --os <os> [options] [--dry-run]"
	echo ""
	echo "  --os              ubuntu2404 | ubuntu2604 | debian-trixie (required)"
	echo "  --with-cuda       CUDA support (default: on)"
	echo "  --cuda-version    13.3 | 13.4, installed from NVIDIA's compute repo (required if CUDA is on)"
	echo "  --opencv-version  5.0.0 | 4.14.0 (default: 5.0.0)"
	echo "  --use-mkl         Intel MKL (linked statically) for BLAS/LAPACK, OpenBLAS if off (default: on)"
	echo "  --with-java       Java bindings (default: off)"
	echo "  --with-python     Python 3 bindings (default: on)"
	echo "  --with-examples   build and install the examples (default: off)"
	echo "  --with-docs       build and install the HTML documentation (default: off)"
	echo "  --dry-run         print the docker command instead of running it"
	echo ""
	echo "Switches take on|off or true|false."
}

die() {
	echo "Error: $*" >&2
	echo "" >&2
	usage >&2
	exit 1
}

# prints on/off for on|true / off|false
parse_switch() {
	case "$2" in
		on|true) echo on ;;
		off|false) echo off ;;
		*) die "$1 must be on|off or true|false (got: '$2')" ;;
	esac
}

os=""
with_cuda=on
cuda_version=""
opencv_version=5.0.0
use_mkl=on
with_java=off
with_python=on
with_examples=off
with_docs=off
dry_run=0

while [ $# -gt 0 ]
do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		--dry-run) dry_run=1; shift; continue ;;
		--*=*) opt="${1%%=*}"; value="${1#*=}"; shift ;;
		--*) opt="$1"; value="${2:?missing value for $1}"; shift 2 ;;
		*) die "unknown argument: $1" ;;
	esac
	case "$opt" in
		--os) os="$value" ;;
		--with-cuda) with_cuda="$value" ;;
		--cuda-version) cuda_version="$value" ;;
		--opencv-version) opencv_version="$value" ;;
		--use-mkl) use_mkl="$value" ;;
		--with-java) with_java="$value" ;;
		--with-python) with_python="$value" ;;
		--with-examples) with_examples="$value" ;;
		--with-docs) with_docs="$value" ;;
		*) die "unknown argument: $opt" ;;
	esac
done

with_cuda=$(parse_switch --with-cuda "$with_cuda")
use_mkl=$(parse_switch --use-mkl "$use_mkl")
with_java=$(parse_switch --with-java "$with_java")
with_python=$(parse_switch --with-python "$with_python")
with_examples=$(parse_switch --with-examples "$with_examples")
with_docs=$(parse_switch --with-docs "$with_docs")

case "$os" in
	ubuntu2404) base_image=ubuntu:24.04; nvidia_repo=ubuntu2404 ;;
	ubuntu2604) base_image=ubuntu:26.04; nvidia_repo=ubuntu2604 ;;
	debian-trixie) base_image=debian:trixie; nvidia_repo=debian13 ;;
	"") die "--os is required" ;;
	*) die "unsupported --os: $os" ;;
esac

case "$opencv_version" in
	5.0|5.0.0) opencv_version=5.0.0 ;;
	4.14|4.14.0) opencv_version=4.14.0 ;;
	*) die "unsupported --opencv-version: $opencv_version" ;;
esac

if [ "$with_cuda" == "on" ]
then
	case "$cuda_version" in
		13.3|13.4) ;;
		"") die "--cuda-version is required when building with CUDA" ;;
		*) die "unsupported --cuda-version: $cuda_version" ;;
	esac
	variant="${os}_opencv-${opencv_version}_cuda-${cuda_version}"
else
	if [ -n "$cuda_version" ]
	then
		echo "Warning: --cuda-version is ignored when building without CUDA" >&2
		cuda_version=""
	fi
	variant="${os}_opencv-${opencv_version}_cpu"
fi

# non-default features end up in the output directory name, so variants don't overwrite each other
[ "$use_mkl" == "off" ] && variant+="_openblas"
[ "$with_java" == "on" ] && variant+="_java"
[ "$with_python" == "off" ] && variant+="_nopython"
[ "$with_examples" == "on" ] && variant+="_examples"
[ "$with_docs" == "on" ] && variant+="_docs"

cd "$(dirname "$0")"
output_dir="output/$variant"
log_file="output/$variant.log"

cmd=(docker build
	--target export
	--output "type=local,dest=$output_dir"
	--progress=plain
	--build-arg "BASE_IMAGE=$base_image"
	--build-arg "NVIDIA_REPO=$nvidia_repo"
	--build-arg "WITH_CUDA=$with_cuda"
	--build-arg "CUDA_VERSION=$cuda_version"
	--build-arg "OPENCV_VERSION=$opencv_version"
	--build-arg "USE_MKL=$use_mkl"
	--build-arg "WITH_JAVA=$with_java"
	--build-arg "WITH_PYTHON=$with_python"
	--build-arg "WITH_EXAMPLES=$with_examples"
	--build-arg "WITH_DOCS=$with_docs"
	.)

if [ "$dry_run" -eq 1 ]
then
	printf '%q ' "${cmd[@]}"
	echo ""
	exit 0
fi

mkdir -p output
echo "Building $variant - this takes several hours (progress log: $log_file)"
"${cmd[@]}" 2>&1 | tee "$log_file"

echo ""
echo "Package and full build log written to $output_dir:"
ls -1 "$output_dir"/*.deb "$output_dir"/build.log
