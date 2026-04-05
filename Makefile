SHELL := /bin/bash
ROOT := $(CURDIR)
PROJECT := $(ROOT)/TinyNet.xcodeproj
SCHEME := TinyNet
CONFIGURATION ?= Debug
CODE_SIGNING_ALLOWED ?= YES
CODE_SIGNING_REQUIRED ?= YES
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
		CODE_SIGNING_ALLOWED="$(CODE_SIGNING_ALLOWED)" \
		CODE_SIGNING_REQUIRED="$(CODE_SIGNING_REQUIRED)" \
		build

run: build-app
	open "$(APP_PATH)"

clean:
	rm -rf "$(ROOT)/.build"
