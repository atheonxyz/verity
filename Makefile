VERSION := $(shell cat VERSION)
PROVEKIT_PATH ?= ../provekit

# ── Core builds ────────────────────────────────────────────────────────

.PHONY: core-ios core-android core-wasm core-native core-all

core-ios:
	bash core/build/build-ios.sh $(PROVEKIT_PATH)

core-android:
	bash core/build/build-android.sh $(PROVEKIT_PATH)

core-wasm:
	bash core/build/build-wasm.sh

core-native:
	bash core/build/build-native.sh

core-all: core-ios core-android core-wasm core-native

# ── SDK tests ──────────────────────────────────────────────────────────

.PHONY: test-swift test-kotlin test-js test-all

test-swift: core-ios
	cd sdks/swift && xcodebuild test \
		-scheme Verity \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		-skipPackagePluginValidation

test-kotlin: core-android
	cd sdks/kotlin && ./gradlew connectedAndroidTest

test-js: core-wasm core-native
	cd sdks/js && npm test

test-all: test-swift test-kotlin test-js

# ── Releases ───────────────────────────────────────────────────────────

.PHONY: release-swift release-kotlin release-js

release-swift: core-ios
	bash sdks/swift/scripts/release.sh $(VERSION)

release-kotlin: core-android
	bash sdks/kotlin/scripts/release.sh $(VERSION)

release-js: core-wasm core-native
	bash sdks/js/scripts/release.sh $(VERSION)

# ── Utilities ──────────────────────────────────────────────────────────

.PHONY: clean

clean:
	rm -rf core/target
	rm -rf sdks/swift/.build sdks/swift/output
	cd sdks/kotlin && ./gradlew clean 2>/dev/null || true
	cd sdks/js && rm -rf node_modules dist 2>/dev/null || true
