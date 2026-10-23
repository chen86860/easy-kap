DERIVED := build/DerivedData
XCODEBUILD := xcodebuild -quiet -project Kap.xcodeproj -scheme Kap -derivedDataPath $(DERIVED)

.PHONY: project build release test lint run clean

project:
	xcodegen generate --quiet

build: project
	$(XCODEBUILD) -destination 'generic/platform=macOS' -configuration Debug build

release: project
	$(XCODEBUILD) -destination 'generic/platform=macOS' -configuration Release ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build
	@echo "→ $(DERIVED)/Build/Products/Release/EasyKap.app"

test: project
	$(XCODEBUILD) -destination 'platform=macOS,arch=arm64' test

lint:
	swiftlint lint --strict --quiet

run: build
	open $(DERIVED)/Build/Products/Debug/EasyKap.app

clean:
	rm -rf build Kap.xcodeproj
