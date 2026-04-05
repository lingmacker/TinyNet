SHELL := /bin/bash
ROOT := $(CURDIR)
PROJECT := $(ROOT)/TinyNet.xcodeproj
SCHEME := TinyNet
CONFIGURATION ?= Debug
DERIVED_DATA := $(ROOT)/.build/DerivedData
APP_PATH := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/TinyNet.app

.PHONY: build-rust build-app run clean

build-rust:
	bash "$(ROOT)/scripts/build_rust.sh"

build-app: build-rust
	xcodebuild \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-sdk macosx \
		-derivedDataPath "$(DERIVED_DATA)" \
		build

run: build-app
	open "$(APP_PATH)"

clean:
	rm -rf "$(ROOT)/.build"
