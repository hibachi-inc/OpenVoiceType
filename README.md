# OpenVoiceText

Context-aware voice input for macOS. Speak into any app and get clean, formatted text — entirely on-device.

**Zero dependencies. Zero network. Zero subscription.**

Built with Apple Speech framework + Apple FoundationModels. No Whisper, no cloud APIs, no model downloads.

## How it works

1. Press **⌥Space** to start recording
2. Speak naturally
3. Press **⌥Space** again to stop
4. Text is refined based on the active app and copied to clipboard
5. **⌘V** to paste

The app detects which app is focused and adjusts refinement style:

| App type | Style | Examples |
|---|---|---|
| Chat | Concise, conversational | Slack, Discord, Messages |
| Email | Polished, complete sentences | Mail, Outlook, Spark |
| Code | Preserves identifiers and symbols | Xcode, VS Code, Cursor |
| Terminal | Preserves commands and flags | Terminal, iTerm, Warp |
| Notes | Structured with bullet points | Notion, Obsidian, Bear |
| Browser | Concise for forms and comments | Safari, Chrome, Arc |
| Generic | Natural, well-formatted text | Everything else |

## Architecture

Three-process design using XPC for crash isolation:

```
OpenVoiceText.app (main process)
├── UI, hotkey, state machine, coordination
│
├── STT Service (XPC)
│   └── SFSpeechRecognizer + AVAudioEngine
│
└── Refiner Service (XPC)
    └── Apple FoundationModels (on-device LLM)
```

If the speech engine crashes, the main app stays alive. If the LLM hangs, it times out and inserts raw text. The UI never freezes.

## Requirements

| Feature | Minimum macOS |
|---|---|
| Voice input (STT only) | macOS 14 Sonoma |
| AI text refinement | macOS 26 Tahoe + Apple Intelligence enabled |

On macOS 14–15, the app works as a voice input tool without AI refinement (raw transcript is used as-is).

FoundationModels requires Apple Silicon and Apple Intelligence to be enabled in System Settings.

## Permissions

The app will request these permissions on first launch:

- **Microphone** — to capture speech
- **Speech Recognition** — for on-device transcription

Both are processed entirely on-device. No audio or text data ever leaves your Mac.

## Build

Requires Xcode 16+ and Swift 6.0+.

```bash
git clone https://github.com/hibachi-inc/OpenVoiceText.git
cd OpenVoiceType
make run
```

This builds all three targets (app + 2 XPC services), assembles the `.app` bundle, signs it ad-hoc, and launches it.

### Build targets

| Target | Description |
|---|---|
| `VoiceFlowApp` | Main app (menu bar, HUD, hotkey) |
| `VoiceFlowSTT` | Speech-to-text XPC service |
| `VoiceFlowRefiner` | Text refinement XPC service |

### Run tests

```bash
swift test
```

36 tests covering the state machine, app context classification, and recording coordinator.

### Direct distribution build

For the direct distribution version (auto-paste via Accessibility API instead of clipboard):

```bash
swift build -Xswiftc -DDIRECT
```

This enables `AccessibilityInjector` which simulates ⌘V to paste text at the cursor position. Requires Accessibility permission.

## Project structure

```
Sources/
├── VoiceFlowApp/          # Main process
│   ├── App/               # Entry point, AppDelegate
│   ├── Core/              # State machine, coordinator, app context
│   ├── Injector/          # ClipboardInjector / AccessibilityInjector
│   ├── UI/                # Floating HUD, SwiftUI views
│   └── XPC/               # XPC client wrappers with timeout
├── VoiceFlowSTT/          # STT XPC service
├── VoiceFlowRefiner/      # Refiner XPC service (FoundationModels)
└── VoiceFlowProtocol/     # Shared XPC protocol definitions
```

## How it compares

| App | STT | Refinement | Context-aware | Fully local | Open source |
|---|---|---|---|---|---|
| **OpenVoiceText** | Apple Speech | Apple FoundationModels | Yes | Yes | Yes (MIT) |
| SuperWhisper | Whisper | Cloud | No | No | No |
| Wispr Flow | Cloud | Cloud | No | No | No |
| VoiceInk | Whisper | Ollama/Cloud | Partial | Partial | Yes |
| Amical | Whisper | Ollama/Cloud | Yes | Partial | Yes |

## Roadmap

- [ ] Settings UI (hotkey customization, language selection, refinement mode)
- [ ] Dictation history panel
- [ ] Push-to-talk + toggle mode selection
- [ ] Personal vocabulary / custom terms
- [ ] App Store distribution (sandboxed build)
- [ ] Sparkle auto-update for direct distribution

## License

[MIT](LICENSE) — Hibachi Inc.

---

Built by Hibachi Inc. — makers of [Reki note](https://rekinote.app/)
