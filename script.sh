# # IOS
# make core-ios PROVEKIT_PATH=../provekit
# # make core-ios PROVEKIT_PATH=../provekit BACKENDS=all
# # Regenerate precompiled schemes (only if it is needed)
# bash scripts/regenerate-schemes.sh
# # Open in Xcode and run (Cmd+R)
# cd examples/ios/VerityDemo
# xcodegen generate
# VERITY_SWIFT_SDK_MODE=native open VerityDemo.xcodeproj


# Android 
# make core-android PROVEKIT_PATH=../provekit                # Both backends
make core-android PROVEKIT_PATH=../provekit BACKENDS=provekit  # PK only (faster)
bash sdks/kotlin/scripts/build-android.sh
bash scripts/regenerate-schemes.sh
cd examples/android/VerityDemo && ./gradlew assembleDebug
# apk is at app/build/outputs/apk/debug/app-debug.apk


# # Tests 
# make test-swift       
# make test-kotlin
# make test-js       