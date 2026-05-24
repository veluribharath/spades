(() => {
  'use strict';

  const STORAGE_KEY = 'spades.apiKey';
  const MODEL_KEY = 'spades.model';
  const DEFAULT_MODEL = 'claude-sonnet-4-6';
  const API_URL = 'https://api.anthropic.com/v1/messages';

  const RANK_VALUE = { '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14 };
  const SUIT_SYMBOL = { S: '♠', H: '♥', D: '♦', C: '♣' };
  const SUIT_NAME = { S: 'Spades', H: 'Hearts', D: 'Diamonds', C: 'Clubs' };

  // ---------- DOM ----------
  const $ = (id) => document.getElementById(id);
  const screens = ['setupScreen', 'captureScreen', 'loadingScreen', 'resultScreen', 'settingsScreen'];
  let lastImageBase64 = null;
  let lastImageMediaType = 'image/jpeg';

  function showScreen(id) {
    screens.forEach((s) => $(s).classList.toggle('hidden', s !== id));
    window.scrollTo({ top: 0, behavior: 'instant' in window ? 'instant' : 'auto' });
  }

  function toast(msg, ms = 2800) {
    const t = $('toast');
    t.textContent = msg;
    t.classList.remove('hidden');
    clearTimeout(toast._t);
    toast._t = setTimeout(() => t.classList.add('hidden'), ms);
  }

  function getKey() { return localStorage.getItem(STORAGE_KEY) || ''; }
  function setKey(k) { localStorage.setItem(STORAGE_KEY, k); }
  function clearKey() { localStorage.removeItem(STORAGE_KEY); }
  function getModel() { return localStorage.getItem(MODEL_KEY) || DEFAULT_MODEL; }
  function setModel(m) { localStorage.setItem(MODEL_KEY, m); }

  // ---------- Image preprocessing ----------
  async function fileToNormalizedJpeg(file, maxDim = 1200, quality = 0.85) {
    const dataUrl = await new Promise((resolve, reject) => {
      const r = new FileReader();
      r.onload = () => resolve(r.result);
      r.onerror = reject;
      r.readAsDataURL(file);
    });

    const img = await new Promise((resolve, reject) => {
      const i = new Image();
      i.onload = () => resolve(i);
      i.onerror = () => reject(new Error('Could not load image. If it\'s a HEIC photo, try saving as JPEG first.'));
      i.src = dataUrl;
    });

    let { width, height } = img;
    if (width > maxDim || height > maxDim) {
      const scale = Math.min(maxDim / width, maxDim / height);
      width = Math.round(width * scale);
      height = Math.round(height * scale);
    }
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(img, 0, 0, width, height);
    const jpegDataUrl = canvas.toDataURL('image/jpeg', quality);
    const base64 = jpegDataUrl.split(',')[1];
    return { base64, mediaType: 'image/jpeg', previewUrl: jpegDataUrl };
  }

  // ---------- Claude vision call ----------
  const VISION_PROMPT = `You are a card recognition assistant. Look at the photo of playing cards in a player's hand.

Return ONLY a single JSON object with this exact shape, no prose:

{
  "cards": [
    { "rank": "A" | "K" | "Q" | "J" | "10" | "9" | "8" | "7" | "6" | "5" | "4" | "3" | "2", "suit": "S" | "H" | "D" | "C" }
  ],
  "uncertain": boolean,
  "notes": "optional short explanation if anything was hard to read"
}

Rules:
- Suits: S=spades, H=hearts, D=diamonds, C=clubs.
- Include EVERY visible card. Do not invent cards you can't see clearly.
- If a card is partially hidden but you can identify both rank and suit, include it.
- If you genuinely cannot identify a card, set "uncertain" to true and describe it in "notes" — do NOT guess.
- No duplicates unless you actually see two of the same card (jokers/unusual decks).
- Output strictly valid JSON. No markdown fences, no commentary.`;

  async function identifyCards(base64, mediaType) {
    const apiKey = getKey();
    if (!apiKey) throw new Error('Missing API key.');

    const res = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true'
      },
      body: JSON.stringify({
        model: getModel(),
        max_tokens: 1024,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'image', source: { type: 'base64', media_type: mediaType, data: base64 } },
              { type: 'text', text: VISION_PROMPT }
            ]
          }
        ]
      })
    });

    if (!res.ok) {
      let detail = '';
      try { const err = await res.json(); detail = err?.error?.message || ''; } catch (_) {}
      if (res.status === 401) throw new Error('Invalid API key. Check it in Settings.');
      if (res.status === 429) throw new Error('Rate limited. Wait a moment and try again.');
      throw new Error(`API error (${res.status}). ${detail}`);
    }

    const data = await res.json();
    const text = data?.content?.[0]?.text || '';
    return parseCardsJSON(text);
  }

  function parseCardsJSON(text) {
    let cleaned = text.trim();
    cleaned = cleaned.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
    const firstBrace = cleaned.indexOf('{');
    const lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      cleaned = cleaned.slice(firstBrace, lastBrace + 1);
    }
    let parsed;
    try { parsed = JSON.parse(cleaned); }
    catch (e) { throw new Error('Could not parse the model response. Try a clearer photo.'); }

    if (!parsed || !Array.isArray(parsed.cards)) {
      throw new Error('No cards detected. Try a clearer photo.');
    }
    const cards = parsed.cards
      .filter((c) => c && RANK_VALUE[c.rank] && SUIT_SYMBOL[c.suit])
      .map((c) => ({ rank: c.rank, suit: c.suit }));
    if (cards.length === 0) throw new Error('No readable cards found. Try better lighting or angle.');
    return { cards, uncertain: !!parsed.uncertain, notes: parsed.notes || '' };
  }

  // ---------- Prediction logic (Progressive Spades) ----------
  // Returns { tricks, confidence: 'low'|'med'|'high', reasoning: string[] }
  function predictTricks(cards) {
    const handSize = cards.length;
    const bySuit = { S: [], H: [], D: [], C: [] };
    cards.forEach((c) => bySuit[c.suit].push(RANK_VALUE[c.rank]));
    Object.keys(bySuit).forEach((s) => bySuit[s].sort((a, b) => b - a)); // desc

    const spades = bySuit.S;
    const reasoning = [];
    let tricks = 0;

    // --- Spade honors ---
    if (spades.includes(14)) {
      tricks += 1;
      reasoning.push('A♠ → 1 sure trick (highest trump).');
    }
    if (spades.includes(13)) {
      if (spades.length >= 2) {
        tricks += 1;
        reasoning.push('K♠ is guarded → 1 likely trick.');
      } else {
        tricks += 0.6;
        reasoning.push('K♠ singleton → can be caught by A♠ (partial credit).');
      }
    }
    if (spades.includes(12)) {
      if (spades.length >= 3) {
        tricks += 0.7;
        reasoning.push('Q♠ with 2+ guards → likely trick.');
      } else if (spades.length === 2) {
        tricks += 0.4;
        reasoning.push('Q♠ with one guard → maybe a trick.');
      } else {
        tricks += 0.1;
        reasoning.push('Q♠ singleton → unlikely to win.');
      }
    }
    if (spades.includes(11) && spades.length >= 4) {
      tricks += 0.4;
      reasoning.push('J♠ with 3+ guards → useful for late tricks.');
    }

    // --- Side-suit aces & kings ---
    ['H', 'D', 'C'].forEach((s) => {
      const suit = bySuit[s];
      if (suit.length === 0) return;
      if (suit.includes(14)) {
        // Aces usually win the first round of their suit.
        tricks += 0.95;
        reasoning.push(`A${SUIT_SYMBOL[s]} → almost always 1 trick on the first round.`);
      }
      if (suit.includes(13)) {
        if (suit.length >= 2) {
          tricks += 0.55;
          reasoning.push(`K${SUIT_SYMBOL[s]} guarded → often wins a trick.`);
        } else {
          // Bare K — likely to fall to the Ace.
          tricks += 0.15;
          reasoning.push(`K${SUIT_SYMBOL[s]} singleton → at risk of falling to the A.`);
        }
      }
      if (suit.includes(12) && suit.length >= 3) {
        tricks += 0.25;
        reasoning.push(`Q${SUIT_SYMBOL[s]} with 2+ guards → occasional trick.`);
      }
    });

    // --- Ruffing potential: long spades + short side suits ---
    // Each spade beyond the 3rd has ruffing value (smaller when round is small).
    const longSpadeBonus = Math.max(0, spades.length - 3);
    if (longSpadeBonus > 0 && handSize >= 5) {
      const ruffValue = Math.min(longSpadeBonus, 4) * 0.45;
      tricks += ruffValue;
      reasoning.push(`${spades.length} spades total → extra ruffing tricks worth ~${ruffValue.toFixed(1)}.`);
    }

    // Voids and singletons in side suits give ruffing tricks IF we have spades to ruff with.
    if (spades.length >= 2 && handSize >= 5) {
      ['H', 'D', 'C'].forEach((s) => {
        const len = bySuit[s].length;
        if (len === 0) {
          tricks += 0.5;
          reasoning.push(`Void in ${SUIT_NAME[s].toLowerCase()} → can ruff right away.`);
        } else if (len === 1 && !bySuit[s].includes(14)) {
          tricks += 0.25;
          reasoning.push(`Singleton in ${SUIT_NAME[s].toLowerCase()} → ruffing chance after 1 round.`);
        }
      });
    }

    // --- Small-hand adjustment ---
    // In 1-2 card rounds, the prediction is mostly about whether you have any high card.
    if (handSize === 1) {
      // One card. Win odds roughly = rank/14 if not a spade; higher if spade.
      const c = cards[0];
      const v = RANK_VALUE[c.rank];
      let p;
      if (c.suit === 'S') p = Math.min(1, v / 14 + 0.15);
      else p = v / 14;
      tricks = p;
      reasoning.length = 0;
      reasoning.push(`1-card round. ${c.rank}${SUIT_SYMBOL[c.suit]} wins ~${Math.round(p * 100)}% of the time.`);
    } else if (handSize === 2) {
      tricks = Math.min(tricks, 2) * 0.85; // dampening — very luck-driven
    }

    // --- Final rounding + clamping ---
    const rawTricks = tricks;
    let predicted = Math.round(tricks);
    predicted = Math.max(0, Math.min(handSize, predicted));

    // Confidence
    let confidence;
    if (handSize <= 2) confidence = 'low';
    else if (handSize <= 6) confidence = 'med';
    else confidence = 'high';

    // If the raw is very close to the rounding boundary, soften confidence one notch.
    const fractional = Math.abs(rawTricks - Math.round(rawTricks));
    if (fractional > 0.35 && confidence !== 'low') {
      confidence = confidence === 'high' ? 'med' : 'low';
    }

    return { tricks: predicted, confidence, reasoning, raw: rawTricks };
  }

  // ---------- Rendering ----------
  function renderResult(parsed) {
    const cards = parsed.cards;
    const pred = predictTricks(cards);

    $('predTricks').textContent = String(pred.tricks);
    const pill = $('confidencePill');
    pill.className = 'pill ' + pred.confidence;
    pill.textContent =
      pred.confidence === 'high' ? 'High confidence' :
      pred.confidence === 'med' ? 'Medium confidence' :
      'Low confidence';

    $('handSize').textContent = String(cards.length);
    $('spadeCount').textContent = String(cards.filter((c) => c.suit === 'S').length);

    const list = $('cardList');
    list.innerHTML = '';
    const sorted = [...cards].sort((a, b) => {
      const order = { S: 0, H: 1, D: 2, C: 3 };
      if (order[a.suit] !== order[b.suit]) return order[a.suit] - order[b.suit];
      return RANK_VALUE[b.rank] - RANK_VALUE[a.rank];
    });
    sorted.forEach((c) => {
      const li = document.createElement('li');
      const isSpade = c.suit === 'S';
      const isStrong = !isSpade && RANK_VALUE[c.rank] >= 13; // A or K of side suit
      const red = c.suit === 'H' || c.suit === 'D';
      li.className = 'card-chip' + (isSpade ? ' spade' : isStrong ? ' strong' : '');
      li.innerHTML = `<span>${c.rank}</span><span class="${red ? 'suit-red' : 'suit-black'}">${SUIT_SYMBOL[c.suit]}</span>`;
      list.appendChild(li);
    });

    const r = $('reasoningList');
    r.innerHTML = '';
    if (pred.reasoning.length === 0) {
      const li = document.createElement('li');
      li.textContent = 'No strong cards — bidding 0 is reasonable.';
      r.appendChild(li);
    } else {
      pred.reasoning.forEach((line) => {
        const li = document.createElement('li');
        li.textContent = line;
        r.appendChild(li);
      });
    }

    if (parsed.uncertain && parsed.notes) {
      const li = document.createElement('li');
      li.style.borderLeftColor = 'var(--warn)';
      li.textContent = `Note from the reader: ${parsed.notes}`;
      r.appendChild(li);
    }

    showScreen('resultScreen');
  }

  // ---------- Event wiring ----------
  function init() {
    // Initial screen
    if (getKey()) showScreen('captureScreen');
    else showScreen('setupScreen');

    // Setup
    $('saveKeyBtn').addEventListener('click', () => {
      const v = $('apiKeyInput').value.trim();
      if (!v) { toast('Please paste a key first.'); return; }
      if (!v.startsWith('sk-ant-')) { toast('That doesn\'t look like an Anthropic key.'); return; }
      setKey(v);
      $('apiKeyInput').value = '';
      toast('Saved.');
      showScreen('captureScreen');
    });

    // Settings nav
    $('settingsBtn').addEventListener('click', () => {
      $('apiKeyEdit').value = getKey();
      $('modelSelect').value = getModel();
      showScreen('settingsScreen');
    });
    $('settingsBackBtn').addEventListener('click', () => {
      showScreen(getKey() ? 'captureScreen' : 'setupScreen');
    });
    $('settingsSaveBtn').addEventListener('click', () => {
      const v = $('apiKeyEdit').value.trim();
      if (v) setKey(v);
      setModel($('modelSelect').value);
      toast('Settings saved.');
      showScreen(getKey() ? 'captureScreen' : 'setupScreen');
    });
    $('clearKeyBtn').addEventListener('click', () => {
      clearKey();
      toast('API key removed.');
      showScreen('setupScreen');
    });

    // Capture
    const fileInput = $('fileInput');
    const previewImg = $('previewImg');
    const preview = $('preview');
    const predictBtn = $('predictBtn');

    fileInput.addEventListener('change', async (e) => {
      const file = e.target.files && e.target.files[0];
      if (!file) return;
      try {
        const { base64, mediaType, previewUrl } = await fileToNormalizedJpeg(file);
        lastImageBase64 = base64;
        lastImageMediaType = mediaType;
        previewImg.src = previewUrl;
        preview.classList.remove('hidden');
        predictBtn.disabled = false;
      } catch (err) {
        toast(err.message || 'Could not load that photo.');
      } finally {
        fileInput.value = '';
      }
    });

    $('retakeBtn').addEventListener('click', () => {
      lastImageBase64 = null;
      preview.classList.add('hidden');
      predictBtn.disabled = true;
    });

    predictBtn.addEventListener('click', async () => {
      if (!lastImageBase64) return;
      if (!getKey()) { showScreen('setupScreen'); return; }
      $('loadingText').textContent = 'Reading your cards…';
      showScreen('loadingScreen');
      try {
        const parsed = await identifyCards(lastImageBase64, lastImageMediaType);
        renderResult(parsed);
      } catch (err) {
        toast(err.message || 'Something went wrong.');
        showScreen('captureScreen');
      }
    });

    $('againBtn').addEventListener('click', () => {
      lastImageBase64 = null;
      preview.classList.add('hidden');
      predictBtn.disabled = true;
      showScreen('captureScreen');
    });
  }

  document.addEventListener('DOMContentLoaded', init);
})();
