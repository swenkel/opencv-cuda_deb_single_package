#!/bin/bash

usage() {
	echo "Usage: $0 [options]"
	echo ""
	echo "  --opencv-version  5.0.0 | 4.14.0 (default: 5.0.0)"
	echo "  --with-cuda       CUDA support (default: on)"
	echo "  --cuda-version    installed CUDA 13.x toolkit to build against (required if CUDA is on)"
	echo "  --use-mkl         Intel MKL (linked statically) for BLAS/LAPACK, OpenBLAS if off (default: on)"
	echo "  --with-java       Java bindings (default: off)"
	echo "  --with-python     Python 3 bindings (default: on)"
	echo "  --with-examples   build and install the examples (default: off)"
	echo "  --with-docs       build and install the HTML documentation (default: off)"
	echo ""
	echo "Switches take on|off or true|false."
}

# prints on/off for on|true / off|false
parse_switch() {
	case "$2" in
		on|true) echo on ;;
		off|false) echo off ;;
		*) echo "$1 must be on|off or true|false (got: '$2')" >&2; return 1 ;;
	esac
}

version=5.0.0
with_cuda=on
cuda_version=""
use_mkl=on
with_java=off
with_python=on
with_examples=off
with_docs=off

while [ $# -gt 0 ]
do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		--*=*) opt="${1%%=*}"; value="${1#*=}"; shift ;;
		--*) opt="$1"; value="${2:?missing value for $1}"; shift 2 ;;
		*) opt="$1" ;;
	esac
	case "$opt" in
		--opencv-version) version="$value" ;;
		--with-cuda) with_cuda="$value" ;;
		--cuda-version) cuda_version="$value" ;;
		--use-mkl) use_mkl="$value" ;;
		--with-java) with_java="$value" ;;
		--with-python) with_python="$value" ;;
		--with-examples) with_examples="$value" ;;
		--with-docs) with_docs="$value" ;;
		*) echo "Unknown argument: $opt"; usage; exit 1 ;;
	esac
done

with_cuda=$(parse_switch --with-cuda "$with_cuda") || exit 1
use_mkl=$(parse_switch --use-mkl "$use_mkl") || exit 1
with_java=$(parse_switch --with-java "$with_java") || exit 1
with_python=$(parse_switch --with-python "$with_python") || exit 1
with_examples=$(parse_switch --with-examples "$with_examples") || exit 1
with_docs=$(parse_switch --with-docs "$with_docs") || exit 1

# accept X.Y as shorthand for X.Y.0
if [[ "$version" =~ ^[0-9]+\.[0-9]+$ ]]
then
	version="$version.0"
fi

case "$version" in
	5.0.0)
		sha256_main_source="b0528f5a1d379d59d4701cb28c36e22214cc51cf64594e5b56f2d3e6c0233095"
		sha256_contrib_source="c58f6344170c39abf187c56f3843b59cab1fd3e89cf19ba2ce25dc061659b27f"
		;;
	4.14.0)
		sha256_main_source="ee8fb9b30eb60850431b4656447080e3737b56e45719c92b67f245950609f86e"
		sha256_contrib_source="4f17abd1bc7f88e19c3380c8de7cbf2d863aced5b5ee8d8934cc7902b67d42c9"
		;;
	*)
		echo "Unsupported OpenCV version: $version (supported: 5.0.0, 4.14.0)"
		exit 1
		;;
esac

# CUDA_ARCH_BIN in debian/rules targets the architectures supported by CUDA 13.x
if [ "$with_cuda" == "on" ] && ! [[ "$cuda_version" =~ ^13\.[0-9]+$ ]]
then
	echo "--cuda-version 13.x is required when building with CUDA (got: '$cuda_version')"
	exit 1
fi

echo "Creating build folders"
if [ -d "./build" ]
then
	if [ -d "./build/opencv-$version" ]
	then
		rm -rf "./build/opencv-$version"
	fi
fi
mkdir -p ./build


echo ""

echo "Downloading and verifying OpenCV sources"
if [ -f "./build/opencv_$version.orig.tar.gz" ]
then
	echo "Existing OpenCV main source found - checking if correct"
	main_sum=$(sha256sum "./build/opencv_$version.orig.tar.gz" | cut -d ' ' -f 1)
	if ! [ "$main_sum" == "$sha256_main_source" ]
	then
		echo "Incorrect checksum - deleting existing OpenCV main source"
		rm -rf "./build/opencv_$version.orig.tar.gz"
	else
		echo "Existing version of OpenCV main source okay"
	fi
fi
if ! [ -f "./build/opencv_$version.orig.tar.gz" ] 
then
	echo "Downloading OpenCV main source"
	curl -L -o "./build/opencv_$version.orig.tar.gz" "https://github.com/opencv/opencv/archive/refs/tags/$version.tar.gz"
	main_sum=$(sha256sum "./build/opencv_$version.orig.tar.gz" | cut -d ' ' -f 1)
fi
if ! [ "$main_sum" == "$sha256_main_source" ]
then
	echo "OpenCV main source downloaded does not match checksum"
	echo "Deleting build folder"
	rm -rf "./build"
	exit 1
fi



if [ -f "./build/opencv_$version.orig-contrib.tar.gz" ] 
then
	echo "Existing OpenCV contrib source found - checking if correct"
	contrib_sum=$(sha256sum "./build/opencv_$version.orig-contrib.tar.gz" | cut -d ' ' -f 1)
	if ! [ "$contrib_sum" == "$sha256_contrib_source" ]
	then
		echo "Incorrect checksum - deleting existing OpenCV contrib source"
		rm -rf "./build/opencv_$version.orig-contrib.tar.gz"
	else
		echo "Existing version of OpenCV contrib source okay"
	fi
fi
if ! [ -f "./build/opencv_$version.orig-contrib.tar.gz" ]
then
	echo "Downloading contrib OpenCV source"
	curl -L -o "./build/opencv_$version.orig-contrib.tar.gz" "https://github.com/opencv/opencv_contrib/archive/refs/tags/$version.tar.gz"
	contrib_sum=$(sha256sum "./build/opencv_$version.orig-contrib.tar.gz" | cut -d ' ' -f 1)
fi
if ! [ "$contrib_sum" == "$sha256_contrib_source" ]
then
	echo "OpenCV contrib source does not match checksum"
	echo "Deleting build folder"
	rm -rf "./build"
	exit 1
fi

echo "Extracting sources"
cd build
tar xf opencv_$version.orig.tar.gz
tar xf opencv_$version.orig-contrib.tar.gz --directory ./opencv-$version/
mv ./opencv-$version/opencv_contrib-$version ./opencv-$version/contrib

# fixes for upstream bugs, applied to the extracted sources
if [ -d "../patches/$version" ]
then
	for patch_file in ../patches/"$version"/*.patch
	do
		echo "Applying $(basename "$patch_file")"
		patch -p1 -d "./opencv-$version" < "$patch_file" || exit 1
	done
fi

echo "Copying build and packaging instructions"
cp -r ../debian ./opencv-$version/

cd ./opencv-$version/

# the package version is taken from the top changelog entry, so it has to match the version built
if ! [ "$(dpkg-parsechangelog -S Version)" == "$version-1" ]
then
	echo "Adding changelog entry for version $version"
	printf 'opencv-cuda (%s-1) stable; urgency=low\n\n  * build of version %s\n\n -- FirstName LastName <firstname.lastname@name.tld>  %s\n' \
		"$version" "$version" "$(date -R)" | cat - debian/changelog > debian/changelog.new
	mv debian/changelog.new debian/changelog
fi

if [ "$with_cuda" == "off" ]
then
	echo "Building without CUDA - binary package is named opencv-cpu"
	sed -i \
		-e 's/^Package: opencv-cuda$/Package: opencv-cpu/' \
		-e 's/^Description: .*/Description: Single package version of OpenCV (CPU only, CUDA disabled)/' \
		debian/control
fi

echo "Building package"
OPENCV_WITH_CUDA="${with_cuda^^}" \
OPENCV_CUDA_VERSION="$cuda_version" \
OPENCV_USE_MKL="${use_mkl^^}" \
OPENCV_WITH_JAVA="${with_java^^}" \
OPENCV_WITH_PYTHON="${with_python^^}" \
OPENCV_WITH_EXAMPLES="${with_examples^^}" \
OPENCV_WITH_DOCS="${with_docs^^}" \
	fakeroot debian/rules binary

