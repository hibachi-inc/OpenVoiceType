<p align="center">
  <img src="Resources/readme-banner.png" alt="OpenVoiceText" width="600">
</p>

<p align="center">
  <a href="https://github.com/hibachi-inc/OpenVoiceText/releases/latest/download/OpenVoiceText.dmg"><img src="https://img.shields.io/badge/Download-DMG-blue?style=for-the-badge" alt="Download DMG"></a>
  &nbsp;
  <a href="https://github.com/hibachi-inc/OpenVoiceText/releases/latest"><img src="https://img.shields.io/badge/Releases-all%20versions-gray?style=for-the-badge" alt="All Releases"></a>
</p>

<p align="center">
  [English](#english) | <a href="#日本語">日本語</a>
</p>

---

<a id="english"></a>

On-device voice input for macOS. Speak into any app and get clean text — no cloud, no subscription.

**Zero dependencies. Zero network. Zero subscription.**

Built with Apple Speech framework. Supports both classic `SFSpeechRecognizer` and Apple Intelligence `SpeechAnalyzer` (macOS 26+).

> **macOS 14+, Apple Silicon** — [Download the latest DMG here](https://github.com/hibachi-inc/OpenVoiceText/releases/latest/download/OpenVoiceText.dmg). Open the `.dmg`, drag the app to Applications, done.

## How it works

1. Press **⌃V** to start recording
2. Speak naturally
3. Press **⌃V** again to stop
4. Text is cleaned up and inserted automatically

### Recognition engines

| Engine | macOS | Features |
|---|---|---|
| Classic (SFSpeechRecognizer) | 14+ | Standard on-device speech recognition |
| Enhanced (Apple Intelligence) | 26+ | Higher accuracy, automatic punctuation, `isFinal` segment confirmation |

The app auto-detects which engine is available. If the Apple Intelligence model isn't installed, it falls back to classic.

### Text cleanup

The built-in refiner removes filler words ("um", "uh", "えーと", "あのー", etc.) and normalizes whitespace. Language is auto-detected.

The Refiner runs as an XPC service — the architecture supports swapping it for more advanced refinement (e.g. FoundationModels) without changing the main app.

## Architecture

Three-process design using XPC for crash isolation:

```
OpenVoiceText.app (main process)
├── UI, hotkey, state machine, coordination
│
├── STT Service (XPC)
│   └── SFSpeechRecognizer / SpeechAnalyzer + AVAudioEngine
│
└── Refiner Service (XPC)
    └── SimpleRefiner (filler removal + whitespace normalization)
```

If the speech engine crashes, the main app stays alive. If the refiner hangs, it times out and inserts raw text. The UI never freezes.

## Requirements

| Feature | Minimum macOS |
|---|---|
| Voice input (classic) | macOS 14 Sonoma |
| Voice input (Apple Intelligence) | macOS 26 Tahoe |

Apple Intelligence engine requires Apple Silicon and Apple Intelligence to be enabled in System Settings.

## Permissions

The app requests permissions when you first start recording:

- **Microphone** — to capture speech
- **Speech Recognition** — for on-device transcription

Both are processed entirely on-device. No audio or text data ever leaves your Mac.

## Build

Requires Xcode 16+ and Swift 6.0+.

```bash
git clone https://github.com/hibachi-inc/OpenVoiceText.git
cd OpenVoiceText
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

74 tests across 4 suites: state machine, app context, recording coordinator, and SimpleRefiner.

### Distribution builds

```bash
make bundle-dmg   # Direct distribution (Hardened Runtime)
make release      # Build + sign + notarize + GitHub Release
```

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
│   ├── App/               # Entry point, AppDelegate, GlobalHotkey
│   ├── Core/              # State machine, coordinator, app context
│   ├── Injector/          # ClipboardInjector / AccessibilityInjector
│   ├── Store/             # PreferencesStore, HistoryStore
│   ├── UI/                # Floating HUD, SwiftUI views, Settings
│   └── XPC/               # XPC client wrappers with timeout
├── VoiceFlowSTT/          # STT XPC service
├── VoiceFlowRefiner/      # Refiner XPC service (SimpleRefiner)
└── VoiceFlowProtocol/     # Shared XPC protocol definitions
```

## Comparison

| App | STT | Refinement | Fully local | Open source |
|---|---|---|---|---|
| **OpenVoiceText** | Apple Speech / Apple Intelligence | Filler removal | Yes | Yes (MIT) |
| SuperWhisper | Whisper | Cloud | No | No |
| Wispr Flow | Cloud | Cloud | No | No |
| VoiceInk | Whisper | Ollama/Cloud | Partial | Yes |
| Amical | Whisper | Ollama/Cloud | Partial | Yes |

## License

[MIT](LICENSE) — Hibachi Inc.

---

<a id="日本語"></a>

# OpenVoiceText（日本語）

macOS向けのオンデバイス音声入力アプリ。あらゆるアプリに話しかけるだけで、整形されたテキストが入力される。

**依存なし。通信なし。サブスクなし。**

Apple Speech フレームワークで構築。従来の `SFSpeechRecognizer` と Apple Intelligence の `SpeechAnalyzer`（macOS 26+）の両方に対応。

## ダウンロード

> **macOS 14以降、Apple Silicon** — [最新版DMGをダウンロード](https://github.com/hibachi-inc/OpenVoiceText/releases/latest/download/OpenVoiceText.dmg)。`.dmg` を開いてアプリをApplicationsにドラッグするだけ。
>
> どれをダウンロードすればいいか分からない場合は、[リリースページ](https://github.com/hibachi-inc/OpenVoiceText/releases/latest)を開いて `.dmg` ファイルをクリック。

## 使い方

1. **⌃V** で録音開始
2. 自然に話す
3. もう一度 **⌃V** で録音停止
4. テキストが整形・挿入される

### 認識エンジン

| エンジン | macOS | 特徴 |
|---|---|---|
| クラシック（SFSpeechRecognizer） | 14+ | 標準のオンデバイス音声認識 |
| 高精度（Apple Intelligence） | 26+ | 高精度認識、自動句読点、isFinalによるセグメント確定 |

利用可能なエンジンを自動検出する。Apple Intelligenceモデルが未インストールの場合はクラシックにフォールバック。

### テキスト整形

内蔵リファイナーがフィラーワード（「um」「uh」「えーと」「あのー」等）を除去し、空白を正規化する。言語は自動検出。

RefinerはXPCサービスとして動作するため、メインアプリを変更せずに高度な整形（例: FoundationModels）に差し替え可能なアーキテクチャになっている。

## アーキテクチャ

XPC によるプロセス分離設計（3プロセス構成）:

```
OpenVoiceText.app（メインプロセス）
├── UI、ホットキー、状態マシン、調整
│
├── STT サービス（XPC）
│   └── SFSpeechRecognizer / SpeechAnalyzer + AVAudioEngine
│
└── Refiner サービス（XPC）
    └── SimpleRefiner（フィラー除去 + 空白正規化）
```

音声エンジンがクラッシュしてもメインアプリは生き残る。リファイナーがハングしてもタイムアウトして生テキストを挿入する。UIがフリーズすることはない。

## 動作要件

| 機能 | 最低macOSバージョン |
|---|---|
| 音声入力（クラシック） | macOS 14 Sonoma |
| 音声入力（Apple Intelligence） | macOS 26 Tahoe |

Apple Intelligenceエンジンは Apple Silicon と、システム設定で Apple Intelligence が有効になっている必要がある。

## 権限

初回録音時に以下の権限を要求する:

- **マイク** — 音声の取り込み
- **音声認識** — オンデバイスでの文字起こし

すべてオンデバイスで処理される。音声やテキストデータがMacの外に送信されることはない。

## ビルド

Xcode 16以降、Swift 6.0以降が必要。

```bash
git clone https://github.com/hibachi-inc/OpenVoiceText.git
cd OpenVoiceText
make run
```

3つのターゲット（アプリ + XPCサービス2つ）をビルドし、`.app` バンドルを組み立て、ad-hoc署名して起動する。

### ビルドターゲット

| ターゲット | 説明 |
|---|---|
| `VoiceFlowApp` | メインアプリ（メニューバー、HUD、ホットキー） |
| `VoiceFlowSTT` | 音声認識 XPC サービス |
| `VoiceFlowRefiner` | テキスト整形 XPC サービス |

### テスト実行

```bash
swift test
```

74テスト（4スイート）: 状態マシン、アプリコンテキスト、録音コーディネーター、SimpleRefiner。

### 直接配布ビルド

アクセシビリティAPI経由の自動ペースト版（クリップボードの代わり）:

```bash
swift build -Xswiftc -DDIRECT
```

`AccessibilityInjector` が有効になり、⌘Vをシミュレートしてカーソル位置にテキストを貼り付ける。アクセシビリティ権限が必要。

## プロジェクト構成

```
Sources/
├── VoiceFlowApp/          # メインプロセス
│   ├── App/               # エントリポイント、AppDelegate
│   ├── Core/              # 状態マシン、コーディネーター、アプリコンテキスト
│   ├── Injector/          # ClipboardInjector / AccessibilityInjector
│   ├── Store/             # PreferencesStore, HistoryStore
│   ├── UI/                # フローティングHUD、SwiftUIビュー
│   └── XPC/               # タイムアウト付きXPCクライアント
├── VoiceFlowSTT/          # STT XPC サービス
├── VoiceFlowRefiner/      # Refiner XPC サービス（SimpleRefiner）
└── VoiceFlowProtocol/     # 共有XPCプロトコル定義
```

## 比較

| アプリ | STT | 整形 | 完全ローカル | OSS |
|---|---|---|---|---|
| **OpenVoiceText** | Apple Speech / Apple Intelligence | フィラー除去 | あり | あり（MIT） |
| SuperWhisper | Whisper | クラウド | なし | なし |
| Wispr Flow | クラウド | クラウド | なし | なし |
| VoiceInk | Whisper | Ollama/クラウド | 一部 | あり |
| Amical | Whisper | Ollama/クラウド | 一部 | あり |

## ライセンス

[MIT](LICENSE) — ヒバチ株式会社

---

Built by [Hibachi Inc.](https://hibachi.co.jp) — makers of [Reki note](https://rekinote.app/)
