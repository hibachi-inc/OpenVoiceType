APP_NAME = VoiceFlow
BUILD_DIR = .build/debug
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

.PHONY: build bundle run clean bundle-mas bundle-dmg

build:
	swift build

bundle: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowApp" "$(APP_BUNDLE)/Contents/MacOS/VoiceFlowApp"
	cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/"
	cp "Resources/PrivacyInfo.xcprivacy" "$(APP_BUNDLE)/Contents/"

	mkdir -p "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowSTT" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS/VoiceFlowSTT"
	cp "Resources/STT-Info.plist" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/Info.plist"

	mkdir -p "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowRefiner" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS/VoiceFlowRefiner"
	cp "Resources/Refiner-Info.plist" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/Info.plist"

	codesign --force --sign - "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc"
	codesign --force --sign - "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc"
	codesign --force --sign - "$(APP_BUNDLE)"

# MAS build: App Sandbox enabled
bundle-mas: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowApp" "$(APP_BUNDLE)/Contents/MacOS/VoiceFlowApp"
	cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/"
	cp "Resources/PrivacyInfo.xcprivacy" "$(APP_BUNDLE)/Contents/"

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

# DMG build: Hardened Runtime, no Sandbox
bundle-dmg: build
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowApp" "$(APP_BUNDLE)/Contents/MacOS/VoiceFlowApp"
	cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/"
	cp "Resources/PrivacyInfo.xcprivacy" "$(APP_BUNDLE)/Contents/"

	mkdir -p "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowSTT" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/MacOS/VoiceFlowSTT"
	cp "Resources/STT-Info.plist" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc/Contents/Info.plist"

	mkdir -p "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS"
	cp "$(BUILD_DIR)/VoiceFlowRefiner" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/MacOS/VoiceFlowRefiner"
	cp "Resources/Refiner-Info.plist" "$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc/Contents/Info.plist"

	codesign --force --sign - --options runtime --entitlements "Resources/Entitlements/STT-XPC-DMG.entitlements" \
		"$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.stt.xpc"
	codesign --force --sign - --options runtime \
		"$(APP_BUNDLE)/Contents/XPCServices/com.hibachi.voiceflow.refiner.xpc"
	codesign --force --sign - --options runtime --entitlements "Resources/Entitlements/App-DMG.entitlements" \
		"$(APP_BUNDLE)"

run: bundle
	open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"
