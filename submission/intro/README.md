# Demo video bookends (intro / outro)

Two branded animations for the 3-minute demo, already rendered to MP4 (1920×1080):

| File | Length | Use |
|---|---|---|
| `dendrite_intro.mp4` | ~11s | Open the video. A single node grows into the dendrite + wordmark. |
| `dendrite_outro.mp4` | ~10s | Close the video. Wordmark, tagline, and your **Code / Live Demo** links. |

Drop these on the ends of your screen recording (see `../VIDEO_SCRIPT.md`).

## Before publishing
Edit the placeholders in `dendrite_outro.html` and re-render:
- `github.com/<you>/Dendrite` → your real repo URL
- `<your-demo-url>` → your hosted demo URL

## Re-render (only if you change the HTML)
Requires Node ≥18 and ffmpeg. A local Playwright lives in `.render/` (gitignored).

```bash
export PATH="/d/nvm/v22.20.0:/d/ffmpeg/win/bin:$PATH"
export NODE_PATH="$PWD/.render/node_modules"
node /d/ProgramData/huashu-design/scripts/render-video.js dendrite_outro.html --duration=10 --width=1920 --height=1080
node /d/ProgramData/huashu-design/scripts/render-video.js dendrite_intro.html --duration=12 --width=1920 --height=1080
```

> Optional: add a music bed / SFX with the huashu-design audio scripts
> (`scripts/add-music.sh`) before assembling — keep it low under narration.
