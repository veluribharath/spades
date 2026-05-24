(() => {
  'use strict';

  // Constants
  const RANK_VALUES = {
    '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
    'J': 11, 'Q': 12, 'K': 13, 'A': 14
  };
  const VALUE_TO_RANK = {
    2: '2', 3: '3', 4: '4', 5: '5', 6: '6', 7: '7', 8: '8', 9: '9', 10: '10',
    11: 'J', 12: 'Q', 13: 'K', 14: 'A'
  };
  const SUIT_SYMBOLS = { S: '♠', H: '♥', D: '♦', C: '♣' };
  const SUIT_NAMES = { S: 'Spades', H: 'Hearts', D: 'Diamonds', C: 'Clubs' };

  // Application State
  const state = {
    hand: {
      S: [], // Spades (array of numerical values)
      H: [], // Hearts
      D: [], // Diamonds
      C: []  // Clubs
    },
    activeSuit: null // 'S', 'H', 'D', or 'C'
  };

  // Helper DOM Selector
  const $ = (id) => document.getElementById(id);

  // Initialize Event Listeners
  function init() {
    // Suit Tabs Click Handlers
    ['S', 'H', 'D', 'C'].forEach(suit => {
      $(`tab${suit}`).addEventListener('click', () => toggleSuitDrawer(suit));
    });

    // Rank Grid Pill Click Handlers
    const rankButtons = document.querySelectorAll('.ranks-grid .rank-pill:not(.none-pill)');
    rankButtons.forEach(button => {
      button.addEventListener('click', () => {
        const rank = button.getAttribute('data-rank');
        toggleCard(rank);
      });
    });

    // "Select None" Button Handler
    $('nonePill').addEventListener('click', clearActiveSuit);

    // Initial render to set up default placeholders
    renderAll();
  }

  // Toggle the active suit selector drawer
  function toggleSuitDrawer(suit) {
    const drawer = $('ranksDrawer');
    
    // If clicking already active suit, close the drawer
    if (state.activeSuit === suit) {
      state.activeSuit = null;
      drawer.classList.remove('open');
      deactivateAllTabs();
      return;
    }

    // Set new active suit
    state.activeSuit = suit;
    
    // Update drawer classes for matching styling theme
    drawer.className = 'ranks-drawer open ' + getSuitClassName(suit);
    $('activeSuitText').innerHTML = `Configuring <strong>${SUIT_NAMES[suit]}</strong>`;

    // Highlight the active suit tab button
    deactivateAllTabs();
    $(`tab${suit}`).classList.add('active');

    // Sync the rank grid pills to match current state of this suit
    syncRankPills();
  }

  // Clear active tab styles
  function deactivateAllTabs() {
    ['S', 'H', 'D', 'C'].forEach(suit => {
      $(`tab${suit}`).classList.remove('active');
    });
  }

  // Map suit character to matching CSS theme class
  function getSuitClassName(suit) {
    if (suit === 'S') return 'spade';
    if (suit === 'C') return 'club';
    if (suit === 'H') return 'heart';
    if (suit === 'D') return 'diamond';
    return '';
  }

  // Add/Remove a card value to/from the active suit
  function toggleCard(rank) {
    if (!state.activeSuit) return;
    
    const suit = state.activeSuit;
    const value = RANK_VALUES[rank];
    const index = state.hand[suit].indexOf(value);

    if (index > -1) {
      // Card exists, so remove it
      state.hand[suit].splice(index, 1);
    } else {
      // Card doesn't exist, so add it
      state.hand[suit].push(value);
    }

    // Keep the array sorted descending
    state.hand[suit].sort((a, b) => b - a);

    // Sync UI
    syncRankPills();
    renderAll();
  }

  // Clear all card selections for the current active suit
  function clearActiveSuit() {
    if (!state.activeSuit) return;
    
    state.hand[state.activeSuit] = [];
    
    // Sync UI
    syncRankPills();
    renderAll();
  }

  // Highlight active rank pills based on state
  function syncRankPills() {
    if (!state.activeSuit) return;

    const suit = state.activeSuit;
    const activeValues = state.hand[suit];
    
    const rankButtons = document.querySelectorAll('.ranks-grid .rank-pill:not(.none-pill)');
    rankButtons.forEach(button => {
      const rank = button.getAttribute('data-rank');
      const val = RANK_VALUES[rank];
      
      if (activeValues.includes(val)) {
        button.classList.add('active');
      } else {
        button.classList.remove('active');
      }
    });
  }

  // Main render coordinator
  function renderAll() {
    renderHandSummary();
    const prediction = calculateTricks();
    renderPrediction(prediction);
  }

  // Renders the visual hand dashboard at the top
  function renderHandSummary() {
    let totalCards = 0;
    const placeholder = $('emptyPlaceholder');

    ['S', 'H', 'D', 'C'].forEach(suit => {
      const row = $(`suitRow${suit}`);
      const chipContainer = $(`suitChips${suit}`);
      const cards = state.hand[suit];

      totalCards += cards.length;

      if (cards.length > 0) {
        row.classList.remove('hidden');
        row.classList.remove('empty');
        chipContainer.innerHTML = '';

        cards.forEach(val => {
          const rank = VALUE_TO_RANK[val];
          const chip = document.createElement('div');
          
          let suitClass = getSuitClassName(suit);
          if (suit === 'H' || suit === 'D') {
            suitClass = 'red';
          }
          
          chip.className = `card-chip ${suitClass}`;
          chip.innerHTML = `<span>${rank}</span><span class="suit-symbol">${SUIT_SYMBOLS[suit]}</span>`;
          chipContainer.appendChild(chip);
        });
      } else {
        row.classList.add('hidden');
        row.classList.add('empty');
        chipContainer.innerHTML = '';
      }
    });

    if (totalCards > 0) {
      placeholder.classList.add('hidden');
    } else {
      placeholder.classList.remove('hidden');
    }
  }

  // Real-Time Progressive Spades Trick Prediction Engine
  function calculateTricks() {
    const spades = state.hand.S;
    const hearts = state.hand.H;
    const diamonds = state.hand.D;
    const clubs = state.hand.C;

    const handSize = spades.length + hearts.length + diamonds.length + clubs.length;
    const reasoning = [];
    let tricks = 0;

    if (handSize === 0) {
      return { tricks: 0, confidence: 'No Bid', reasoning: [], handSize, spadeCount: 0 };
    }

    // --- 1. Spade (Trump) Honors ---
    if (spades.includes(14)) {
      tricks += 1.0;
      reasoning.push({ text: 'A♠ → 1 sure trick (highest trump card).', type: 'trump-reason' });
    }
    if (spades.includes(13)) {
      if (spades.length >= 2) {
        tricks += 1.0;
        reasoning.push({ text: 'K♠ is guarded by other spades → 1 likely trick.', type: 'trump-reason' });
      } else {
        tricks += 0.6;
        reasoning.push({ text: 'K♠ singleton → vulnerable to falling under the A♠ (partial credit).', type: 'trump-reason' });
      }
    }
    if (spades.includes(12)) {
      if (spades.length >= 3) {
        tricks += 0.7;
        reasoning.push({ text: 'Q♠ with 2+ guards → highly likely to pull a trick.', type: 'trump-reason' });
      } else if (spades.length === 2) {
        tricks += 0.4;
        reasoning.push({ text: 'Q♠ with only 1 guard → moderate chance of winning.', type: 'trump-reason' });
      } else {
        tricks += 0.1;
        reasoning.push({ text: 'Q♠ singleton → highly likely to get caught.', type: 'trump-reason' });
      }
    }
    if (spades.includes(11) && spades.length >= 4) {
      tricks += 0.4;
      reasoning.push({ text: 'J♠ with 3+ guards → strong potential for late-round wins.', type: 'trump-reason' });
    }

    // --- 2. Side-Suit Honors ---
    ['H', 'D', 'C'].forEach(s => {
      const suit = state.hand[s];
      const symbol = SUIT_SYMBOLS[s];
      const suitName = SUIT_NAMES[s];

      if (suit.length === 0) return;

      if (suit.includes(14)) {
        tricks += 0.95;
        reasoning.push({ text: `A${symbol} → almost certain trick in the first round of ${suitName}.`, type: 'side-suit-reason' });
      }
      if (suit.includes(13)) {
        if (suit.length >= 2) {
          tricks += 0.55;
          reasoning.push({ text: `K${symbol} guarded → likely trick if the Ace is pulled early.`, type: 'side-suit-reason' });
        } else {
          tricks += 0.15;
          reasoning.push({ text: `K${symbol} singleton → high risk of falling to the Ace.`, type: 'side-suit-reason' });
        }
      }
      if (suit.includes(12) && suit.length >= 3) {
        tricks += 0.25;
        reasoning.push({ text: `Q${symbol} with 2+ guards → minor value on long rounds.`, type: 'side-suit-reason' });
      }
    });

    // --- 3. Ruffing Potential (Short Side-Suits + Long Spades) ---
    // In Progressive Spades, ruffing requires having a reasonable hand size
    const longSpadeCount = Math.max(0, spades.length - 3);
    if (longSpadeCount > 0 && handSize >= 5) {
      const ruffValue = Math.min(longSpadeCount, 4) * 0.45;
      tricks += ruffValue;
      reasoning.push({ text: `Ruffing potential with ${spades.length} Spades → adding ~${ruffValue.toFixed(1)} tricks.`, type: 'special-reason' });
    }

    // Short-suits offer ruffing if we have spades to control
    if (spades.length >= 2 && handSize >= 5) {
      ['H', 'D', 'C'].forEach(s => {
        const len = state.hand[s].length;
        const name = SUIT_NAMES[s].toLowerCase();
        const symbol = SUIT_SYMBOLS[s];

        if (len === 0) {
          tricks += 0.5;
          reasoning.push({ text: `Void in ${name} ${symbol} → can trump/ruff on the first round of the suit.`, type: 'special-reason' });
        } else if (len === 1 && !state.hand[s].includes(14)) {
          tricks += 0.25;
          reasoning.push({ text: `Singleton in ${name} ${symbol} → rapid entry to ruffing in later rounds.`, type: 'special-reason' });
        }
      });
    }

    // --- 4. Micro Hand adjustments ---
    const rawTricks = tricks;
    
    if (handSize === 1) {
      // 1-card round: Trick odds purely determined by rank weight
      const allSuits = ['S', 'H', 'D', 'C'];
      let activeCard = null;
      let activeSuit = null;
      
      allSuits.forEach(s => {
        if (state.hand[s].length === 1) {
          activeCard = state.hand[s][0];
          activeSuit = s;
        }
      });

      if (activeCard) {
        let p = activeCard / 14;
        if (activeSuit === 'S') {
          p = Math.min(1.0, p + 0.15); // Trump bonus
        }
        tricks = p;
        
        reasoning.length = 0; // Clear other calculations
        reasoning.push({ 
          text: `1-card round: ${VALUE_TO_RANK[activeCard]}${SUIT_SYMBOLS[activeSuit]} wins approximately ${Math.round(p * 100)}% of the time in standard play.`, 
          type: 'special-reason' 
        });
      }
    } else if (handSize === 2) {
      // 2-card round: Extremely high variance, dampen predictions slightly
      tricks = Math.min(tricks, 2.0) * 0.85;
    }

    // Rounding and Clamping
    let finalPrediction = Math.round(tricks);
    finalPrediction = Math.max(0, Math.min(handSize, finalPrediction));

    // Confidence Metrics
    let confidence = 'med';
    if (handSize <= 2) {
      confidence = 'low';
    } else if (handSize >= 7) {
      confidence = 'high';
    }

    // If mathematical raw score is near the boundary, lower confidence slightly
    const fraction = Math.abs(rawTricks - Math.round(rawTricks));
    if (fraction > 0.35 && confidence !== 'low') {
      confidence = confidence === 'high' ? 'med' : 'low';
    }

    return {
      tricks: finalPrediction,
      confidence,
      reasoning,
      handSize,
      spadeCount: spades.length
    };
  }

  // Render prediction outputs onto UI
  function renderPrediction(p) {
    const numberDiv = $('predTricks');
    const circle = $('predictionCircle');
    const confidence = $('confidencePill');
    const list = $('reasoningList');

    $('handSize').textContent = String(p.handSize);
    $('spadeCount').textContent = String(p.spadeCount);

    if (p.handSize === 0) {
      numberDiv.textContent = '—';
      circle.classList.remove('has-bid');
      
      confidence.className = 'confidence-pill low';
      confidence.textContent = 'No Bid';
      
      list.innerHTML = `<li class="empty-reason">Select cards above to calculate your expected Progressive Spades bid.</li>`;
      return;
    }

    // Add glowing color highlights if predicted tricks are greater than 0
    numberDiv.textContent = String(p.tricks);
    if (p.tricks > 0) {
      circle.classList.add('has-bid');
    } else {
      circle.classList.remove('has-bid');
    }

    // Set confidence classes
    confidence.className = `confidence-pill ${p.confidence}`;
    confidence.textContent = p.confidence + ' confidence';

    // Render detailed reasoning bullets
    list.innerHTML = '';
    if (p.reasoning.length === 0) {
      list.innerHTML = `<li class="empty-reason">No points/high card power detected. Bidding 0 is highly recommended.</li>`;
    } else {
      p.reasoning.forEach(item => {
        const li = document.createElement('li');
        li.className = item.type;
        li.textContent = item.text;
        list.appendChild(li);
      });
    }
  }

  // Start on content load
  document.addEventListener('DOMContentLoaded', init);
})();
