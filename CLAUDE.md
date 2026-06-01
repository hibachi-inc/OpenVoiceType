# OpenVoiceText — CLAUDE.md

## プロジェクト概要

macOS ネイティブ音声入力アプリ。XPC プロセス分離アーキテクチャ。

## リポジトリ構成

| リポジトリ | 公開 | 内容 |
|---|---|---|
| `hibachi-inc/OpenVoiceText` | PUBLIC (MIT) | メインアプリ + STT XPC + SimpleRefiner XPC |
| `hibachi-inc/OpenVoiceText-Pro` | PRIVATE | Pro Refiner XPC（FoundationModels 整形 + 翻訳） |

### OSS 版（このリポ）に含まれるもの
- VoiceFlowApp: メインプロセス（UI、HUD、ホットキー、Settings、履歴）
- VoiceFlowSTT: 音声認識 XPC サービス（SFSpeechRecognizer）
- VoiceFlowRefiner: **SimpleRefiner**（passthrough + 軽い整形のみ）
- VoiceFlowProtocol: XPC プロトコル定義（STT + Refiner）

### Pro 版（別リポ）に含まれるもの
- ProRefiner: FoundationModels による AI 整形 + 多言語翻訳
- 翻訳 Settings UI
- このリポを git submodule で参照

### 有料機能の境界
- **XPC プロトコル（RefinerServiceProtocol）が契約**
- `refine(text:category:reply:)` と `translate(text:targetLanguage:reply:)` を実装する XPC サービスを差し替えるだけ
- メインアプリは Refiner の実装詳細を知らない

## ビルド

```bash
make run        # OSS 版（SimpleRefiner）
swift test      # テスト実行
```

## アーキテクチャ

```
VoiceFlowApp (メインプロセス)
├── UI: FloatingHUD, MainWindow (Settings/Hotkey/Translation/History/About)
├── Core: RecordingStateMachine, RecordingCoordinator, AppContext
├── Injector: ClipboardInjector / AccessibilityInjector (#if DIRECT)
├── Store: PreferencesStore (UserDefaults), HistoryStore (SwiftData)
├── XPC Clients: STTXPCClient, RefinerXPCClient (with timeout)
│
├── VoiceFlowSTT.xpc — SFSpeechRecognizer + AVAudioEngine
└── VoiceFlowRefiner.xpc — SimpleRefiner (OSS) / ProRefiner (有料)
```

## ホットキー
- Carbon Hot Key API (RegisterEventHotKey) — Input Monitoring 権限不要
- 通常録音: デフォルト ⌥Space
- 翻訳: 言語ごとにショートカット（⌃E→English, ⌃J→Japanese 等）— Pro 版のみ

## テスト
- RecordingStateMachine: 全遷移パス
- AppContext: 全7カテゴリ分類
- RecordingCoordinator: DI で全依存をモック化、フロー検証
