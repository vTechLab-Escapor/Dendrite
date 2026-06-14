<div align="center">

# 🌿 Dendrite

### Think in branches, not lines.

**An AI-native, non-linear mobile knowledge space.**

[![License: MIT](https://img.shields.io/badge/License-MIT-10A37F.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-555.svg)]()

</div>

---

## What is Dendrite?

Conventional AI chat is a **straight line** — every reply pushes the last one out of view, and exploring a tangent means abandoning your main thread. Dendrite breaks the timeline open.

In Dendrite, a conversation is a **tree**. Highlight any phrase in any message and spawn a **branch** that explores it — without losing your place. Every thread of thought lives on, navigable through a live **mind-map** of your whole conversation. It's named after the *dendrites* of a neuron: the branching structures through which thought actually spreads.

> **One question. Many directions. Nothing lost.**

---

## ✨ Key Features

| | Feature | Description |
|---|---|---|
| 🌳 | **Non-linear branching** | Select any text in any reply and branch off it. Each branch carries its selection as context, so the AI knows exactly what you're drilling into. |
| 🗺️ | **Live mind-map canvas** | The entire conversation rendered as an interactive tree. Pan, zoom, tap a node to jump there. The active lineage is highlighted; bookmarked nodes are starred. |
| 🧠 | **Lineage-aware context** | The model only ever sees the ancestor path of your current node (a single recursive SQL CTE), not the whole tree — focused context, lower token cost. |
| 🔀 | **Multi-provider AI** | One engine, three wire dialects: **OpenAI-compatible** (NVIDIA NIM, ModelScope, OpenAI, Grok, Xiaomi…), **Anthropic**, and **Google Gemini**. Switch in Settings. |
| ⚡ | **True real-time streaming** | Token-by-token SSE via `dart:io` `HttpClient`, deliberately bypassing the Android `HttpURLConnection` buffering that stalls `package:http`. |
| 💭 | **Visible reasoning** | A system prompt elicits step-by-step `<think>…</think>` reasoning, rendered distinctly from the final answer. |
| 🔖 | **Bookmarks & search** | Star key nodes and find any message across all conversations. |
| 📎 | **Attachments & Markdown** | Pick files into the conversation; replies render as rich Markdown. |
| 🔒 | **Local-first & secure** | All history in on-device SQLite (Drift). API keys live in the platform secure store (Keychain / Keystore) — never in plaintext. |
| 🎨 | **Premium UI** | ChatGPT-style editorial design, floating capsule input, custom Dendrite vector logo, light/dark themes. |

---

## 🏗️ Architecture

```
lib/
├── main.dart                       # App entry, theming
├── core/
│   ├── agent/agent_engine.dart     # Multi-dialect SSE streaming engine (OpenAI/Anthropic/Gemini)
│   ├── db/database.dart            # Drift schema, recursive-CTE lineage queries, search
│   ├── models/api_config.dart      # Provider configuration
│   └── utils/id_generator.dart
└── features/
    ├── chat/
    │   ├── chat_cubit.dart         # State (flutter_bloc): branching, send, search, bookmarks
    │   ├── chat_repository.dart    # Persistence boundary
    │   ├── chat_tree.dart          # Pure, unit-tested tree navigation
    │   └── widgets/                # chat_screen, selection_menu
    ├── map/widgets/                # mind_map_canvas — interactive tree visualisation
    └── settings/                   # settings_repository — secure key storage
```

- **State management:** `flutter_bloc` (`ChatCubit`) over repositories.
- **Persistence:** `drift` + `sqlite3`, lineage resolved with a single `WITH RECURSIVE` CTE.
- **Tree logic** is isolated in `chat_tree.dart` (no UI/DB deps) so branching is unit-testable.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.x** (Dart `>=3.0.0`)
- An API key from any supported provider (e.g. a free [NVIDIA NIM](https://build.nvidia.com/) or [ModelScope](https://modelscope.cn/) key)

### Run locally
```bash
# 1. Install dependencies
flutter pub get

# 2. Generate the Drift database code
dart run build_runner build --delete-conflicting-outputs

# 3. Launch (mobile or desktop)
flutter run
```

Then open **Settings** inside the app, pick a provider, paste your API key, and choose a model. Keys are stored securely on-device.

> **Optional — bundle a key at build time** (so testers don't need their own):
> ```bash
> flutter run --dart-define=NVIDIA_API_KEY=your_key_here
> ```
> Supported defines: `NVIDIA_API_KEY`, `MODELSCOPE_API_KEY`.

### Build for the Web (Hosted Demo)
```bash
flutter build web --release --dart-define=NVIDIA_API_KEY=your_key_here
```
The static site lands in `build/web/` — deploy that folder to any static host (Netlify, GitHub Pages, Firebase Hosting, Vercel). See [`deploy/README.md`](deploy/README.md) for one-command recipes.

---

## 🔌 Data Sources

Dendrite stores **no data on any server** — every conversation lives in an on-device SQLite database. The only external calls are the AI inference requests you configure:

| Provider | Dialect | Endpoint |
|---|---|---|
| NVIDIA NIM | OpenAI-compatible | `integrate.api.nvidia.com/v1` |
| ModelScope | OpenAI-compatible | `api-inference.modelscope.cn/v1` |
| OpenAI / Grok / Xiaomi / … | OpenAI-compatible | provider-defined |
| Anthropic | Anthropic Messages | `…/messages` |
| Google Gemini | Gemini | `…/models/{model}:streamGenerateContent` |

You bring your own key; Dendrite never proxies it through a third party.

---

## 🧪 Tests
```bash
flutter test
```
Tree-navigation logic and the database layer are covered by unit tests.

---

## 📄 License

Released under the [MIT License](LICENSE).
