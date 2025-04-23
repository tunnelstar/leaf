#!/usr/bin/env sh

set -ex

# Ensure Xcode environment is properly set up
export DEVELOPER_DIR="$(xcode-select -p)"

# Function to set SDK paths based on target
set_sdk_paths() {
	local target=$1
	if [[ $target == *"-ios-sim"* ]] || [[ $target == *"x86_64-apple-ios"* ]]; then
		export SDKROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)"
		# For simulator builds, we need to handle the target differently
		if [[ $target == "aarch64-apple-ios-sim" ]]; then
			# Use ios-sim target but with proper architecture specification
			export BINDGEN_EXTRA_CLANG_ARGS="-isysroot $SDKROOT \
				-target arm64-apple-ios-simulator \
				-I$SDKROOT/usr/include \
				-F$SDKROOT/System/Library/Frameworks \
				-arch arm64"
			export AWS_LC_SYS_EFFECTIVE_TARGET="arm64-apple-ios-simulator"
			export AWS_LC_SYS_CFLAGS="-target arm64-apple-ios-simulator"
		else
			export BINDGEN_EXTRA_CLANG_ARGS="-isysroot $SDKROOT \
				-target x86_64-apple-ios-simulator \
				-I$SDKROOT/usr/include \
				-F$SDKROOT/System/Library/Frameworks \
				-arch x86_64"
			export AWS_LC_SYS_EFFECTIVE_TARGET="x86_64-apple-ios-simulator"
			export AWS_LC_SYS_CFLAGS="-target x86_64-apple-ios-simulator"
		fi
	else
		export SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
		export BINDGEN_EXTRA_CLANG_ARGS="-isysroot $SDKROOT \
			-target arm64-apple-ios \
			-I$SDKROOT/usr/include \
			-F$SDKROOT/System/Library/Frameworks"
		export AWS_LC_SYS_EFFECTIVE_TARGET="arm64-apple-ios"
		export AWS_LC_SYS_CFLAGS="-target arm64-apple-ios"
	fi
	export CFLAGS="-isysroot $SDKROOT $AWS_LC_SYS_CFLAGS"
	export CXXFLAGS="$CFLAGS"
}

mode=release
release_flag=--release
package=leaf-ffi
name=leaf
lib=lib$name.a

# The script is assumed to run in the root of the workspace
base=$(dirname "$0")

# Debug or release build?
if [ "$1" = "debug" ]; then
	mode=debug
	release_flag=
fi

export IPHONEOS_DEPLOYMENT_TARGET=13.0
export MACOSX_DEPLOYMENT_TARGET=10.12

# Build for all desired targets
# rustup target add x86_64-apple-darwin
# rustup target add aarch64-apple-darwin
rustup target add aarch64-apple-ios
rustup target add x86_64-apple-ios
rustup target add aarch64-apple-ios-sim
# cargo build -p $package $release_flag --no-default-features --features "default-aws-lc outbound-quic" --target x86_64-apple-darwin
# cargo build -p $package $release_flag --no-default-features --features "default-aws-lc outbound-quic" --target aarch64-apple-darwin
# cargo build -p $package $release_flag --no-default-features --features "default-aws-lc" --target aarch64-apple-ios
# cargo build -p $package $release_flag --no-default-features --features "default-aws-lc" --target x86_64-apple-ios
# cargo build -p $package $release_flag --no-default-features --features "default-aws-lc" --target aarch64-apple-ios-sim

# Clean previous builds to avoid any cached issues
cargo clean

# Build for iOS device (arm64)
set_sdk_paths "aarch64-apple-ios"
cargo build -p $package $release_flag --no-default-features --features "vmess-only" --target aarch64-apple-ios

# Build for iOS simulator (x86_64)
set_sdk_paths "x86_64-apple-ios"
cargo build -p $package $release_flag --no-default-features --features "vmess-only" --target x86_64-apple-ios

# Build for iOS simulator (arm64)
set_sdk_paths "aarch64-apple-ios-sim"
cargo build -p $package $release_flag --no-default-features --features "vmess-only" --target aarch64-apple-ios-sim

cargo install --force cbindgen

# Directories to put the libraries.
rm -rf target/apple/$mode
mkdir -p target/apple/$mode/include
mkdir -p target/apple/$mode/ios
mkdir -p target/apple/$mode/ios-sim
# mkdir -p target/apple/$mode/macos

# Put built libraries to folders where we can find them easier later
cp target/aarch64-apple-ios/$mode/$lib target/apple/$mode/ios/
# strip symbols
cp target/apple/$mode/ios/$lib target/apple/$mode/ios/$lib.bak
strip -x target/apple/$mode/ios/$lib
lipo -create \
	-arch x86_64 target/x86_64-apple-ios/$mode/$lib \
	-arch arm64 target/aarch64-apple-ios-sim/$mode/$lib \
	-output target/apple/$mode/ios-sim/$lib
# Create a single library for multiple archs
# lipo -create \
# 	-arch x86_64 target/x86_64-apple-darwin/$mode/$lib \
# 	-arch arm64 target/aarch64-apple-darwin/$mode/$lib \
# 	-output target/apple/$mode/macos/$lib
# Generate the header file
cbindgen \
	--config $package/cbindgen.toml \
	$package/src/lib.rs > target/apple/$mode/include/$name.h

wd="$base/../target/apple/$mode"

# Remove existing artifact
rm -rf "$wd/$name.xcframework"

# A modulemap is required for the compiler to find the module when using Swift
cat << EOF > "$wd/include/module.modulemap"
module $name {
    header "$name.h"
    export *
}
EOF

# Create the XCFramework packaging both iOS and macOS static libraries, so we can
# use a single XCFramework for both platforms.
xcodebuild -create-xcframework \
	-library "$wd/ios/$lib" \
	-headers "$wd/include" \
	-library "$wd/ios-sim/$lib" \
	-headers "$wd/include" \
	-output "$wd/$name.xcframework"

ls $wd/$name.xcframework
open $wd
