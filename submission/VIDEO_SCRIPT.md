# Dendrite — 3-Minute Demo Video Script & Storyboard

**Total target: 2:55** (stay under 3:00 — only the first 3 min are judged).
**Language:** English narration (record VO or use TTS). Add English subtitles regardless.
**Structure:** Animated intro (huashu-design) → live screen recording → animated outro.

> 🎬 The animated **intro** and **outro** are pre-rendered (`submission/intro/`).
> Everything in between is a screen recording of the real app. Record the app at
> 1080p portrait (or framed in a phone mock), then cut the three pieces together.

---

## ⏱️ Shot list

| # | Time | Visual | Narration (VO) |
|---|------|--------|----------------|
| **0** | 0:00–0:12 | **ANIMATED INTRO** (`intro/dendrite_intro.html` → MP4). A single node sprouts branches into the Dendrite logo; tagline resolves. | *"This is how we talk to AI today — one message after another, in a single straight line. But thinking doesn't work that way."* |
| **1** | 0:12–0:25 | Screen rec: app open on a normal chat. User asks a broad question (e.g. *"Explain how black holes form."*), answer streams in token-by-token. | *"Meet Dendrite — an AI knowledge space where every conversation is a tree, not a feed. Notice the answer streams in real time."* |
| **2** | 0:25–0:50 | User **highlights a phrase** in the reply (e.g. "event horizon"). The selection menu appears → tap **Branch**. A new branch opens focused on that idea. | *"Here's the core idea. Highlight any phrase — and branch. Dendrite spins off a new line of inquiry about exactly that, carrying your selection as context. Your main thread is untouched."* |
| **3** | 0:50–1:10 | In the branch, ask a follow-up. Then highlight something in *that* answer and branch again — go two levels deep. | *"Branches can branch. Chase a tangent as far as you want — every detour becomes its own explorable thread instead of burying what came before."* |
| **4** | 1:10–1:35 | Tap the **mind-map** view. The whole conversation appears as an interactive tree; pan/zoom; the active path glows green. Tap a node to jump back to the main trunk. | *"Open the mind-map and you see the shape of your thinking. The glowing path is where you are now. Tap any node to teleport straight to that moment in the conversation."* |
| **5** | 1:35–1:55 | Back in chat: **star/bookmark** a key node (it turns gold in the map). Then open **search**, type a term, jump to a result across chats. | *"Star the nodes that matter — they light up gold on the map. And search finds any message across every conversation you've had."* |
| **6** | 1:55–2:20 | Open **Settings**: show provider switcher (NVIDIA / Anthropic / Gemini / OpenAI-compatible). Switch model, send one message to prove it streams from a different provider. | *"Under the hood, one engine speaks to NVIDIA, OpenAI, Anthropic, and Gemini. Bring your own key — it's stored in your device's secure enclave, and every conversation stays local on your phone."* |
| **7** | 2:20–2:35 | Quick montage: light/dark toggle, the empty-state with prompt capsules, smooth scrolling. | *"It's local-first, private, and built in Flutter for Android, iOS, and the web — wrapped in a UI we sweated every pixel of."* |
| **8** | 2:35–2:55 | **ANIMATED OUTRO** (`intro/dendrite_outro.html` → MP4). Logo + tagline "Think in branches, not lines." + repo / demo URLs. | *"Dendrite. Think in branches, not lines. Try the live demo and explore the code — links below."* |

---

## 🎙️ Production notes
- **Record the app in English.** ⚠️ Some default strings are currently bilingual/Chinese
  (e.g. the empty mind-map message and the seeded chat title). Either start a fresh
  English conversation for the demo, or localize those strings before recording
  (see `What's next` in DEVPOST.md). Avoid showing Chinese-only UI on camera.
- **Pace the streaming shots.** The token-by-token stream is a selling point — don't
  speed-ramp over it. Let one answer visibly stream.
- **Keep cuts tight.** Each branch action should be 2–3 seconds; trim dead air.
- **Subtitles:** burn in English subtitles (required if VO isn't crystal clear, and
  good practice regardless). The huashu intro/outro already include on-screen text.
- **No third-party trademarks on screen** beyond the provider names you legitimately
  integrate (fine to say "NVIDIA / Gemini" as integrations; don't show their logos).
- **Music:** a calm tech bed. The intro/outro MP4s can be rendered with BGM via the
  huashu-design audio pipeline if you want; keep it low under narration.

## ✂️ Assembly (any editor — CapCut / DaVinci / Premiere)
1. Drop `dendrite_intro.mp4` on the timeline.
2. Add the screen recording, cut to the shot list above.
3. End with `dendrite_outro.mp4`.
4. Add VO + subtitles + music bed.
5. Export 1080p, **confirm runtime ≤ 2:59**, upload to YouTube/Vimeo as **Public**.
