APP_NAME = OpenVoiceText
BUILD_DIR = .build/debug
RELEASE_DIR = .build/arm64-apple-macosx/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
RELEASE_BUNDLE = $(RELEASE_DIR)/$(APP_NAME).app
VERSION = $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DMG_NAME = $(APP_NAME).dmg
SIGN_ID = Developer ID Application: HIBACHI inc. (TYX92DB6TA)
NOTARY_PROFILE = rekinote-notarize
DIRECT_FLAGS = -Xswiftc -DDIRECT
EMBED_PLIST = -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Resources/Info.plist

.PHONY: build build-release bundle run clean bundle-mas bundle-dmg release dmg notarize

build:
	swift build $(DIRECT_FLAGS) $(EMBED_PLIST)

build-release:
	swift build -c release $(DIRECT_FLAGS) $(EMBED_PLIST)

bundle: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowApp" "$(APP_BUNDLE)/Contents/MacOS/VoiceFlowApp"
	cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/"
	cp "Resources/PrivacyInfo.xcprivacy" "$(APP_BUNDLE)/Contents/Resources/"
	cp -R "Resources/en.lproj" "$(APP_BUNDLE)/Contents/Resources/"
	cp -R "Resources/ja.lproj" "$(APP_BUNDLE)/Contents/Resources/"

	mkdir -p "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowSTT" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS/VoiceFlowSTT"
	cp "Resources/STT-Info.plist" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/Info.plist"

	mkdir -p "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowRefiner" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS/VoiceFlowRefiner"
	cp "Resources/Refiner-Info.plist" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/Info.plist"

	codesign --force --sign "$(SIGN_ID)" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc"
	codesign --force --sign "$(SIGN_ID)" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc"
	codesign --force --sign "$(SIGN_ID)" "$(APP_BUNDLE)"

# MAS build: App Sandbox enabled
bundle-mas: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowApp" "$(APP_BUNDLE)/Contents/MacOS/VoiceFlowApp"
	cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "Resources/AppIcon.icns" "$(APP_BUNDLE)/Contents/Resources/"
	cp "Resources/PrivacyInfo.xcprivacy" "$(APP_BUNDLE)/Contents/Resources/"
	cp -R "Resources/en.lproj" "$(APP_BUNDLE)/Contents/Resources/"
	cp -R "Resources/ja.lproj" "$(APP_BUNDLE)/Contents/Resources/"

	mkdir -p "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowSTT" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS/VoiceFlowSTT"
	cp "Resources/STT-Info.plist" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/Info.plist"

	mkdir -p "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowRefiner" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS/VoiceFlowRefiner"
	cp "Resources/Refiner-Info.plist" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/Info.plist"

	codesign --force --sign - --entitlements "Resources/Entitlements/STT-XPC.entitlements" \
		"$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc"
	codesign --force --sign - --entitlements "Resources/Entitlements/Refiner-XPC.entitlements" \
		"$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc"
	codesign --force --sign - --entitlements "Resources/Entitlements/App-MAS.entitlements" \
		"$(APP_BUNDLE)"

# DMG build: Hardened Runtime, no Sandbox, Developer ID signed
bundle-dmg: build-release
	rm -rf "$(RELEASE_BUNDLE)"
	mkdir -p "$(RELEASE_BUNDLE)/Contents/MacOS"
	cp "$(RELEASE_DIR)/VoiceFlowApp" "$(RELEASE_BUNDLE)/Contents/MacOS/VoiceFlowApp"
	cp "Resources/Info.plist" "$(RELEASE_BUNDLE)/Contents/"
	mkdir -p "$(RELEASE_BUNDLE)/Contents/Resources"
	cp "Resources/AppIcon.icns" "$(RELEASE_BUNDLE)/Contents/Resources/"
	cp "Resources/PrivacyInfo.xcprivacy" "$(RELEASE_BUNDLE)/Contents/Resources/"
	cp -R "Resources/en.lproj" "$(RELEASE_BUNDLE)/Contents/Resources/"
	cp -R "Resources/ja.lproj" "$(RELEASE_BUNDLE)/Contents/Resources/"

	mkdir -p "$(RELEASE_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS"
	cp "$(RELEASE_DIR)/VoiceFlowSTT" "$(RELEASE_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS/VoiceFlowSTT"
	cp "Resources/STT-Info.plist" "$(RELEASE_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/Info.plist"

	mkdir -p "$(RELEASE_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS"
	cp "$(RELEASE_DIR)/VoiceFlowRefiner" "$(RELEASE_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS/VoiceFlowRefiner"
	cp "Resources/Refiner-Info.plist" "$(RELEASE_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/Info.plist"

	codesign --force --sign "$(SIGN_ID)" --options runtime --entitlements "Resources/Entitlements/STT-XPC-DMG.entitlements" \
		"$(RELEASE_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc"
	codesign --force --sign "$(SIGN_ID)" --options runtime \
		"$(RELEASE_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc"
	codesign --force --sign "$(SIGN_ID)" --options runtime --entitlements "Resources/Entitlements/App-DMG.entitlements" \
		"$(RELEASE_BUNDLE)"

dmg: bundle-dmg
	rm -f "$(DMG_NAME)"
	create-dmg \
		--volname "$(APP_NAME)" \
		--background "Resources/dmg-background.png" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 80 \
		--icon "$(APP_NAME).app" 180 200 \
		--app-drop-link 480 200 \
		--no-internet-enable \
		"$(DMG_NAME)" "$(RELEASE_BUNDLE)"
	codesign --force --sign "$(SIGN_ID)" "$(DMG_NAME)"

notarize: dmg
	xcrun notarytool submit "$(DMG_NAME)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(DMG_NAME)"

release: notarize
	git tag "v$(VERSION)"
	git push origin "v$(VERSION)"
	gh release create "v$(VERSION)" "$(DMG_NAME)" \
		--title "$(APP_NAME) v$(VERSION)" \
		--generate-notes

run: bundle
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
