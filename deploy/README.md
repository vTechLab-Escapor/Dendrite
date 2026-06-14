# Deploying the Dendrite Web build

Dendrite compiles to a static site, so any static host works. Build first:

```bash
flutter build web --release --dart-define=NVIDIA_API_KEY=your_key_here
```

Output is in `build/web/`. Pick a host below.

> **Note on routing:** Flutter Web is a single-page app. Every host config here
> rewrites unknown paths back to `index.html` so deep links / refreshes work.

---

## Option A — Netlify (fastest, drag-and-drop or CLI)

A `netlify.toml` is included at the repo root.

**CLI:**
```bash
npm i -g netlify-cli
netlify deploy --prod --dir=build/web
```

**Drag-and-drop:** zip `build/web/` and drop it on https://app.netlify.com/drop

---

## Option B — GitHub Pages

```bash
# from repo root, after `flutter build web`
flutter build web --release --base-href=/Dendrite/   # repo name as base path
npx gh-pages -d build/web
```
Then enable Pages → branch `gh-pages` in repo Settings. URL:
`https://<user>.github.io/Dendrite/`

> The `--base-href` must match the repo name for assets to resolve on Pages.

---

## Option C — Firebase Hosting

```bash
npm i -g firebase-tools
firebase login
firebase init hosting        # set public dir to: build/web ; SPA rewrite: Yes
firebase deploy --only hosting
```

A ready `firebase.json` is included — point its `public` at `build/web`.

---

## Hosted-demo checklist (for judges)

- [ ] Built with a working `--dart-define` key **or** instruct judges to paste their own in Settings.
- [ ] Confirm CORS: some providers block browser-origin requests. NVIDIA NIM and
      OpenAI-compatible endpoints generally allow it; if a provider 403s in the
      browser, note an alternate provider in the demo instructions.
- [ ] Test the deployed URL in an incognito window before submitting.
