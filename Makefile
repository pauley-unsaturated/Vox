# Makefile for AnalogThing AUv3 Synthesizer Project

# Configuration
XCODE_PROJECT = AnalogThing.xcodeproj
SCHEME = AnalogThing
TEST_SCHEME = AnalogThingTests
BUILD_DIR = build
CONFIGURATION = Debug

# Default target
all: build

# Create Xcode project (placeholder until we have a proper script)
project:
	@echo "Please create an Xcode project using Xcode's GUI or with a dedicated script."
	@echo "Then place it in this directory as $(XCODE_PROJECT)"

# Build the plugin
build:
	./build.sh

# Run the tests
test:
	./test.sh

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	rm -rf ~/Library/Developer/Xcode/DerivedData/AnalogThing-*

# Help
help:
	@echo "AnalogThing Build System"
	@echo "-----------------------"
	@echo "Available targets:"
	@echo "  all       : Build the plugin (default)"
	@echo "  project   : Placeholder for Xcode project creation"
	@echo "  build     : Build the plugin"
	@echo "  test      : Run the tests"
	@echo "  clean     : Remove build artifacts"

.PHONY: all project build test clean help