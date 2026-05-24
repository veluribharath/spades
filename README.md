# Spades Trick Predictor

A standalone web app that scans a photo of your card hand and predicts how many tricks you'll win in **Progressive Spades** (1→13 card rounds, no Nil, no bag penalty).

It uses Claude vision to read your cards, then runs a local prediction model tuned for the Progressive Spades variant.

## How it works

1. Open the app in a browser.
2. First-run setup: paste your Anthropic API key. It's stored only in your browser's `localStorage` — never sent anywhere except directly to Anthropic.
3. Tap the camera area, snap (or pick) a photo of your fanned-out hand.
4. Tap **Predict my tricks**. You'll see:
   - Predicted bid (whole number)
   - Confidence pill (Low / Medium / High — scales with hand size)
   - Every detected card, color-coded (blue = spade trump, green = side-suit Ace/King)
   - Plain-English reasoning for each contributing card

## Hosting

The app is three static files: `index.html`, `styles.css`, `app.js`. No build step.

### Option 1 — GitHub Pages
1. Create a new repo, push these files to `main`.
2. Repo → **Settings** → **Pages** → Source: `main` / `/ (root)`.
3. Wait ~30s, then open `https://<your-user>.github.io/<repo>/`.

### Option 2 — Netlify Drop
1. Go to https://app.netlify.com/drop.
2. Drag the project folder onto the page.
3. Done — you get a free `*.netlify.app` URL instantly.

### Option 3 — Vercel
```bash
npm i -g vercel
vercel deploy
```

### Option 4 — Local file (personal use)
Open `index.html` directly in your browser. Works offline except for the Claude API call.

## Getting an API key

1. Sign in at [console.anthropic.com](https://console.anthropic.com/).
2. Go to **API Keys** → **Create Key**.
3. Add a few dollars of credit (vision calls are cheap — fractions of a cent per scan).
4. Paste the key into the app's setup screen.

## Privacy

- Your API key is stored in browser `localStorage`. Click **Forget my API key** in Settings to remove it.
- Photos are sent to Anthropic's API and then discarded by the browser; nothing is uploaded to any other server.
- There is no backend, no analytics, no tracking.

## Sharing

Since each user provides their own API key, you can share the URL freely without worrying about cost. People you share with will need to grab their own free Anthropic account to use it.

## Tweaking the prediction model

The Progressive Spades prediction logic lives in `predictTricks()` inside `app.js`. The current weights are tuned for a variant with:

- 4 players, partnerships
- 1→13 card progression
- No Nil bid
- No bag penalty (1 point per overtrick, no cap)

If you play a different variant, adjust those weights.

## Notes / limitations

- The vision model needs all card ranks and suits visible. Fan your hand and use decent lighting.
- HEIC photos from iPhone are auto-converted in the browser by re-drawing them through a canvas — if a HEIC file fails to load, save it as JPEG first.
- The model used defaults to Claude Sonnet 4.6. Switch to Haiku 4.5 in Settings for cheaper/faster runs, or Opus 4.7 for maximum accuracy on tough photos.
