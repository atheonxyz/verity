VERSION := $(shell cat VERSION)
PROVEKIT_PATH ?= ../provekit
BACKENDS ?=

# ── Core builds ────────────────────────────────────────────────────────

.PHONY: core-ios core-android core-wasm core-native core-all

core-ios:
	bash core/build/build-ios.sh $(PROVEKIT_PATH) $(if $(BACKENDS),--backends $(BACKENDS))

core-android:
	bash core/build/build-android.sh $(PROVEKIT_PATH) $(if $(BACKENDS),--backends $(BACKENDS))

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
	bash core/release/release-ios.sh $(VERSION)

release-kotlin: core-android
	bash core/release/release-android.sh $(VERSION)

release-js: core-wasm core-native
	bash core/release/release-js.sh $(VERSION)

# ── Lint & Format ─────────────────────────────────────────────────────

.PHONY: lint fmt check

lint:
	cd core && cargo clippy --all-targets -- -D warnings
	cd sdks/js && npm run lint 2>/dev/null || npx tsc --noEmit

fmt:
	cd core && cargo fmt
	cd sdks/js && npx prettier --write src/ tests/ 2>/dev/null || true

check: lint
	cd core && cargo test --no-run
	cd sdks/swift && swift build 2>/dev/null || true
	cd sdks/js && npx tsc --noEmit

# ── Utilities ──────────────────────────────────────────────────────────

.PHONY: clean version

version:
	@cat VERSION

clean:
	rm -rf core/target
	rm -rf sdks/swift/.build sdks/swift/output
	cd sdks/kotlin && ./gradlew clean 2>/dev/null || true
	cd sdks/js && rm -rf node_modules dist 2>/dev/null || true
