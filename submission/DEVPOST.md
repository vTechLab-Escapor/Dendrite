# Dendrite — Devpost Submission

> Copy/paste these into the Devpost form fields. Track is left blank — pick the
> one closest to "AI / Productivity / Mobile" for your hackathon.

---

## Project name
**Dendrite**

## Tagline (one line)
Think in branches, not lines — an AI-native, non-linear mobile knowledge space.

## Track
`[ Select the AI / Productivity / Best Mobile App track for your event ]`

## Elevator pitch (≈ 200 chars)
Dendrite turns AI chat from a single scrolling timeline into an explorable tree. Highlight any phrase, branch a new line of inquiry, and navigate everything through a live mind-map — nothing gets lost.

---

## Inspiration
Every AI chat app is a straight line. The moment you chase an interesting tangent, your main thread scrolls into oblivion — and if you want to compare two answers, you're copy-pasting between sessions. But thinking isn't linear. It branches, like the **dendrites** of a neuron. We wanted a tool whose *shape* matched the shape of thought.

## What it does
Dendrite is a mobile knowledge space where a conversation is a **tree**, not a feed:
- **Branch from any selection.** Highlight a phrase in any reply and spawn a new branch that explores just that idea. The selection travels with the branch as context, so the model knows exactly what you're drilling into.
- **See the whole shape.** A live, pannable **mind-map** renders every node of the conversation. Tap any node to jump there; the active path glows, bookmarks are starred.
- **Focused context.** The model only sees the *ancestor lineage* of your current node — resolved in one recursive SQL query — so tangents stay cheap and on-topic.
- **Any model.** NVIDIA, ModelScope, OpenAI, Grok, Anthropic, and Gemini all work through one streaming engine.
- **Yours, locally.** Every conversation lives in on-device SQLite; API keys sit in the secure enclave, never on a server.

## How we built it
- **Flutter** for a single codebase across Android, iOS, and Web.
- **`flutter_bloc` + repositories** for state; the pure tree-navigation logic (`chat_tree.dart`) is decoupled from UI and DB so branching is unit-testable.
- **Drift / SQLite** for local-first storage, with a `WITH RECURSIVE` CTE that walks a node's ancestry in a single query to build model context.
- **A custom multi-dialect streaming engine** (`agent_engine.dart`) that speaks OpenAI-compatible, Anthropic, and Gemini wire formats and parses all three SSE schemas into one token stream.
- **`dart:io` `HttpClient`** for genuine token-by-token streaming — chosen specifically to bypass Android's `HttpURLConnection` buffering that makes `package:http` feel laggy.
- **`flutter_secure_storage`** (Keychain / Keystore) for API keys, with automatic migration off any legacy plaintext.
- A hand-built **mind-map canvas** using `InteractiveViewer` + a `CustomPainter` that draws cubic-curve links and highlights the active lineage.

## Challenges we ran into
- **Real streaming on Android.** `package:http` buffers SSE until the response completes; we dropped to `dart:io` `HttpClient` and hand-parsed `data:` frames to get true real-time deltas.
- **One engine, three dialects.** OpenAI, Anthropic, and Gemini differ in endpoint shape, auth (header vs. query param), request body, *and* per-chunk JSON. We unified them behind a single `ApiDialect` switch.
- **Context from a tree.** "What does the model see?" is obvious in a list and subtle in a tree. The recursive-CTE lineage walk was the key insight — context = the path from root to the active node, nothing more.
- **Auto-centering the map** on the active node across pan/zoom transforms took careful matrix math.

## Accomplishments we're proud of
- A branching UX that genuinely feels faster than linear chat for research and exploration.
- A clean separation that makes the tree logic testable in isolation.
- Provider-agnostic streaming that "just works" across six+ backends.
- A polished, editorial UI with a custom vector logo and light/dark themes.

## What we learned
- The right **data structure** can change a product category: modeling chat as a tree (not a list) unlocked branching, the mind-map, and cheaper context all at once.
- Platform HTTP stacks have opinions; sometimes you go one layer lower to get the UX you want.
- Abstracting provider differences early kept the feature work fast later.

## What's next for Dendrite
- Drag-to-merge branches and side-by-side branch comparison.
- Full-text (FTS5) semantic search across the knowledge space.
- Shareable/exportable conversation trees.
- Per-branch model selection (cheap model for breadth, strong model for depth).
- More UI languages (the app ships English-first with a built-in language switcher: EN/中文/日本語/FR/DE/ES/KO).

## Built with
`flutter` · `dart` · `flutter_bloc` · `drift` · `sqlite3` · `dart:io` · `flutter_secure_storage` · `flutter_markdown` · `nvidia-nim` · `anthropic` · `gemini` · `openai`

## Data sources
No server-side data store. Conversations persist only in **on-device SQLite**. The sole external calls are AI inference requests to the user's chosen provider (NVIDIA NIM, ModelScope, OpenAI-compatible endpoints, Anthropic, Google Gemini), authenticated with the user's own key held in the device secure store.

## Links
- **Repository:** `[ paste public GitHub URL once published ]`
- **Hosted demo:** `[ paste deployed web URL ]`
- **Demo video:** `[ paste YouTube/Vimeo URL ]`
