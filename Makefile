VERSION := $(shell cat VERSION)
PROVEKIT_PATH ?= ../provekit
BACKENDS ?=
CARGO_PROFILE ?= release-mobile

# ── Core builds ────────────────────────────────────────────────────────

.PHONY: core-ios core-android core-wasm core-native core-all js-artifacts test-js-e2e

core-ios:
	CARGO_PROFILE=$(CARGO_PROFILE) bash core/build/build-ios.sh $(PROVEKIT_PATH) $(if $(BACKENDS),--backends $(BACKENDS))

core-android:
	CARGO_PROFILE=$(CARGO_PROFILE) bash core/build/build-android.sh $(PROVEKIT_PATH) $(if $(BACKENDS),--backends $(BACKENDS))

core-wasm:
	bash core/build/build-wasm.sh

core-native:
	bash core/build/build-native.sh

core-all: core-ios core-android core-wasm core-native

# ── SDK tests ──────────────────────────────────────────────────────────

.PHONY: test-swift test-kotlin test-js test-all

test-swift: core-ios test-fixtures
	cd sdks/swift && xcodebuild test \
		-scheme Verity \
		-destination 'platform=iOS Simulator,name=iPhone 16' \
		-skipPackagePluginValidation

test-kotlin: core-android test-fixtures
	cd sdks/kotlin && ./gradlew connectedAndroidTest

test-js: core-wasm js-artifacts
	cd sdks/js && npm test

js-artifacts:
	bash scripts/generate-js-artifacts.sh $(PROVEKIT_PATH)

test-js-e2e: core-wasm js-artifacts
	cd sdks/js && npm run build
	cd examples/js/browser-example && npm install && npm run test:e2e

test-all: test-fixtures test-swift test-kotlin test-js

# ── Fixture generation (for tests) ────────────────────────────────────

.PHONY: test-fixtures

test-fixtures: core-native
	@echo "Generating test fixtures..."
	bash tests/gen-fixtures.sh


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
