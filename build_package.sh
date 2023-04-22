#!/bin/bash

version=4.7.0
sha256_main_source="8df0079cdbe179748a18d44731af62a245a45ebf5085223dc03133954c662973"
sha256_contrib_source="42df840cf9055e59d0e22c249cfb19f04743e1bdad113d31b1573d3934d62584"

echo "Creating build folders"
if [ -d "./build" ]
then
	if [ -d "./build/opencv-$version" ]
	then
		rm -rf "./build/opencv-$version" ]
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

echo "Copying build and packaging instructions"
cp -r ../debian ./opencv-$version/

cd ./opencv-$version/
echo "Building package"
fakeroot debian/rules binary

