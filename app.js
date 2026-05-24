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
      S: [], // Spades (duplicates allowed: e.g. [14, 14, 13])
      H: [], // Hearts
      D: [], // Diamonds
      C: []  // Clubs
    },
    activeSuit: null, // 'S', 'H', 'D', or 'C'
    decks: 2, // Number of decks (1, 2, or 3)
    players: 4, // Number of players (2 to 8)
    activeTab: 'predictor', // 'predictor' or 'scorekeeper'
    
    // Scorekeeper Match Tracking
    scorekeeper: {
      rules: 'progressive', // 'progressive' or 'standard'
      teamAName: 'Team A',
      teamBName: 'Team B',
      teamAScore: 0,
      teamBScore: 0,
      teamABags: 0,
      teamBBags: 0,
      rounds: [] // Array of { roundNumber, bidA, actualA, scoreA, bagsA, bidB, actualB, scoreB, bagsB }
    }
  };

  // Helper DOM Selector
  const $ = (id) => document.getElementById(id);

  // Initialize Event Listeners
  function init() {
    // 1. Suit Tabs Click Handlers
    ['S', 'H', 'D', 'C'].forEach(suit => {
      const tab = $(`tab${suit}`);
      if (tab) {
        tab.addEventListener('click', () => toggleSuitDrawer(suit));
      }
    });

    // 2. Rank Grid Pill Click Handlers
    const rankButtons = document.querySelectorAll('.ranks-grid .rank-pill:not(.none-pill)');
    rankButtons.forEach(button => {
      button.addEventListener('click', () => {
        const rank = button.getAttribute('data-rank');
        toggleCard(rank);
      });
    });

    // 3. "Select None" Button Handler
    const noneBtn = $('nonePill');
    if (noneBtn) {
      noneBtn.addEventListener('click', clearActiveSuit);
    }

    // 4. Game Configuration: Decks Selectors
    const deckButtons = document.querySelectorAll('#deckPills .settings-pill-btn');
    deckButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        deckButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const newDecks = parseInt(btn.getAttribute('data-decks'));
        changeDecks(newDecks);
      });
    });

    // 5. Game Configuration: Players Selectors
    const playerButtons = document.querySelectorAll('#playerPills .settings-pill-btn');
    playerButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        playerButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        state.players = parseInt(btn.getAttribute('data-players'));
        updateSettingsInfo();
        updateConfigHeaderSummary();
        renderAll();
      });
    });

    // 5b. Collapsible Game Configuration Panel Accordion Trigger
    const configHeader = $('configHeader');
    if (configHeader) {
      configHeader.addEventListener('click', () => {
        $('configPanel').classList.toggle('expanded');
      });
    }

    // 5c. Collapsible Real-Time Prediction Panel Accordion Trigger
    const predictionHeader = $('predictionHeader');
    if (predictionHeader) {
      predictionHeader.addEventListener('click', () => {
        $('predictionPanel').classList.toggle('expanded');
      });
    }

    // 6. Navigation Tabs Event Handlers
    const navPredictor = $('tabPredictor');
    if (navPredictor) {
      navPredictor.addEventListener('click', () => switchTab('predictor'));
    }
    const navScorekeeper = $('tabScorekeeper');
    if (navScorekeeper) {
      navScorekeeper.addEventListener('click', () => switchTab('scorekeeper'));
    }

    // 7. Scorekeeper: Rules Selection Listener
    const rulesSel = $('rulesSelect');
    if (rulesSel) {
      rulesSel.addEventListener('change', (e) => {
        state.scorekeeper.rules = e.target.value;
        recalculateMatch();
      });
    }

    // 8. Scorekeeper: Submit Round Handler
    const submitBtn = $('submitRoundBtn');
    if (submitBtn) {
      submitBtn.addEventListener('click', submitRound);
    }

    // 9. Scorekeeper: Reset Match Handler
    const resetBtn = $('resetMatchBtn');
    if (resetBtn) {
      resetBtn.addEventListener('click', resetMatch);
    }

    // 10. Scorekeeper: Custom Team Name Dynamic Listeners
    const nameInputA = $('teamANameInput');
    const nameInputB = $('teamBNameInput');
    
    if (nameInputA) {
      nameInputA.addEventListener('input', () => {
        state.scorekeeper.teamAName = nameInputA.value.trim() || 'Team A';
        updateUIWithTeamNames();
      });
    }
    if (nameInputB) {
      nameInputB.addEventListener('input', () => {
        state.scorekeeper.teamBName = nameInputB.value.trim() || 'Team B';
        updateUIWithTeamNames();
      });
    }

    // Initial render to set up default placeholders & info labels
    updateSettingsInfo();
    updateUIWithTeamNames();
    updateConfigHeaderSummary();
    renderAll();
    renderScoreboard();
  }

  // Switch navigation tabs
  function switchTab(tabId) {
    if (state.activeTab === tabId) return;

    state.activeTab = tabId;
    
    // Toggle active classes on nav tab buttons
    $('tabPredictor').classList.toggle('active', tabId === 'predictor');
    $('tabScorekeeper').classList.toggle('active', tabId === 'scorekeeper');

    // Toggle visibility on container screen panels
    $('predictorScreen').classList.toggle('hidden', tabId !== 'predictor');
    $('scorekeeperScreen').classList.toggle('hidden', tabId !== 'scorekeeper');
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
      const tab = $(`tab${suit}`);
      if (tab) {
        tab.classList.remove('active');
      }
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

  // Handle deck settings change + automatic hand duplicate clamping
  function changeDecks(newDecks) {
    state.decks = newDecks;
    
    // Auto-clamp any existing card selections in our hand
    ['S', 'H', 'D', 'C'].forEach(suit => {
      const cards = state.hand[suit];
      const counts = {};
      const clampedCards = [];
      
      // Traverse cards in order
      cards.forEach(val => {
        counts[val] = (counts[val] || 0) + 1;
        if (counts[val] <= newDecks) {
          clampedCards.push(val);
        }
      });
      
      state.hand[suit] = clampedCards;
    });
    
    updateSettingsInfo();
    updateConfigHeaderSummary();
    syncRankPills();
    renderAll();
  }

  // Update Game Info text based on decks and players
  function updateSettingsInfo() {
    const totalCards = state.decks * 52;
    const maxHand = Math.min(13, Math.floor(totalCards / state.players));
    const info = $('settingsInfo');
    if (info) {
      info.textContent = `${state.decks} ${state.decks === 1 ? 'Deck' : 'Decks'} (${totalCards} cards) with ${state.players} players. Maximum hand size is ${maxHand} cards.`;
    }
  }

  // Update Collapsible Config Summary text based on decks and players
  function updateConfigHeaderSummary() {
    const summary = $('configHeaderSummary');
    if (summary) {
      summary.textContent = `${state.decks} Deck${state.decks > 1 ? 's' : ''} • ${state.players} Players`;
    }
  }

  // Add/Remove card value supporting multi-deck duplicates
  function toggleCard(rank) {
    if (!state.activeSuit) return;
    
    const suit = state.activeSuit;
    const value = RANK_VALUES[rank];
    
    // Count existing copies of this card value in this suit
    const currentCount = state.hand[suit].filter(v => v === value).length;

    if (currentCount < state.decks) {
      // Add another copy
      state.hand[suit].push(value);
    } else {
      // Reached maximum allowed, reset all copies of this card back to 0
      state.hand[suit] = state.hand[suit].filter(v => v !== value);
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

  // Highlight active rank pills and overlay counter badges based on state
  function syncRankPills() {
    if (!state.activeSuit) return;

    const suit = state.activeSuit;
    const activeValues = state.hand[suit];
    
    const rankButtons = document.querySelectorAll('.ranks-grid .rank-pill:not(.none-pill)');
    rankButtons.forEach(button => {
      const rank = button.getAttribute('data-rank');
      const val = RANK_VALUES[rank];
      
      // Calculate how many copies are selected
      const count = activeValues.filter(v => v === val).length;
      const badge = button.querySelector('.rank-badge');
      
      if (count > 0) {
        button.classList.add('active');
        badge.textContent = `x${count}`;
        badge.style.display = 'block';
      } else {
        button.classList.remove('active');
        badge.textContent = '';
        badge.style.display = 'none';
      }
    });
  }

  // Main render coordinator
  function renderAll() {
    renderHandSummary();
    const prediction = calculateTricks();
    renderPrediction(prediction);
  }

  // Renders the visual hand dashboard, showing duplicate cards
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

        // Render each card (duplicates will naturally render side-by-side)
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

  // Real-Time Heuristic Prediction Engine factoring in Decks and Players
  function calculateTricks() {
    const spades = state.hand.S;
    const hearts = state.hand.H;
    const diamonds = state.hand.D;
    const clubs = state.hand.C;

    const handSize = spades.length + hearts.length + diamonds.length + clubs.length;
    const players = state.players;
    const decks = state.decks;
    
    const reasoning = [];
    let tricks = 0;

    if (handSize === 0) {
      return { tricks: 0, confidence: 'No Bid', reasoning: [], handSize, spadeCount: 0 };
    }

    // Dynamic player count factor (opponents void scaling)
    // base players: 4. More players = side honors less secure. Fewer = side honors more secure.
    const playerFactor = (players - 4) * (players > 4 ? -0.04 : -0.02);

    // --- 1. Spade (Trump) Honors Heuristics ---
    const aceSpadesCount = spades.filter(v => v === 14).length;
    if (aceSpadesCount > 0) {
      // In multi-deck, Aces are secure only if you hold all copies
      const secure = decks - aceSpadesCount === 0;
      const valPerAce = secure ? 1.0 : 0.95;
      const totalAceVal = aceSpadesCount * valPerAce;
      tricks += totalAceVal;
      reasoning.push({
        text: `${aceSpadesCount}x A♠ → ${secure ? '100% secure' : 'highly likely'} trick${aceSpadesCount > 1 ? 's' : ''} (${totalAceVal.toFixed(2)} total).`,
        type: 'trump-reason'
      });
    }

    const kingSpadesCount = spades.filter(v => v === 13).length;
    if (kingSpadesCount > 0) {
      // Guarded check: at least 2 spades per King
      const isGuarded = spades.length >= (2 * kingSpadesCount);
      const secure = decks - kingSpadesCount === 0;
      const valPerKing = isGuarded ? (secure ? 1.0 : 0.9) : 0.6;
      const totalKingVal = kingSpadesCount * valPerKing;
      tricks += totalKingVal;
      reasoning.push({
        text: `${kingSpadesCount}x K♠ → ${isGuarded ? 'guarded' : 'unguarded'} value (${totalKingVal.toFixed(2)} total).`,
        type: 'trump-reason'
      });
    }

    const queenSpadesCount = spades.filter(v => v === 12).length;
    if (queenSpadesCount > 0) {
      const isGuarded = spades.length >= (3 * queenSpadesCount);
      const valPerQueen = isGuarded ? 0.7 : (spades.length >= (2 * queenSpadesCount) ? 0.4 : 0.1);
      const totalQueenVal = queenSpadesCount * valPerQueen;
      tricks += totalQueenVal;
      reasoning.push({
        text: `${queenSpadesCount}x Q♠ → ${isGuarded ? 'well-guarded' : 'weakly guarded'} value (${totalQueenVal.toFixed(2)} total).`,
        type: 'trump-reason'
      });
    }

    // --- 2. Side-Suit Honors Heuristics ---
    ['H', 'D', 'C'].forEach(s => {
      const suit = state.hand[s];
      const symbol = SUIT_SYMBOLS[s];
      const suitName = SUIT_NAMES[s];

      if (suit.length === 0) return;

      // Side Aces
      const aceCount = suit.filter(v => v === 14).length;
      if (aceCount > 0) {
        const valPerAce = Math.max(0.55, 0.95 + playerFactor);
        const secure = decks - aceCount === 0;
        const totalVal = aceCount * valPerAce * (secure ? 1.0 : 0.9);
        tricks += totalVal;
        
        let reasonStr = `${aceCount}x A${symbol}`;
        if (players !== 4) {
          reasonStr += ` (${players} players scale: ${valPerAce.toFixed(2)}/each)`;
        }
        reasonStr += ` → expected trick${aceCount > 1 ? 's' : ''} (${totalVal.toFixed(2)} total).`;
        
        reasoning.push({ text: reasonStr, type: 'side-suit-reason' });
      }

      // Side Kings
      const kingCount = suit.filter(v => v === 13).length;
      if (kingCount > 0) {
        const isGuarded = suit.length >= (2 * kingCount);
        const valPerKing = Math.max(0.1, (isGuarded ? 0.55 : 0.15) + playerFactor);
        const secure = decks - kingCount === 0;
        const totalVal = kingCount * valPerKing * (secure ? 1.0 : 0.9);
        tricks += totalVal;

        let reasonStr = `${kingCount}x K${symbol} (${isGuarded ? 'guarded' : 'unguarded'}`;
        if (players !== 4) {
          reasonStr += `, ${players} players scale: ${valPerKing.toFixed(2)}/each`;
        }
        reasonStr += `) → ${totalVal.toFixed(2)} tricks.`;
        
        reasoning.push({ text: reasonStr, type: 'side-suit-reason' });
      }

      // Side Queens
      const queenCount = suit.filter(v => v === 12).length;
      if (queenCount > 0) {
        const isGuarded = suit.length >= (3 * queenCount);
        const valPerQueen = Math.max(0.05, (isGuarded ? 0.25 : 0.05) + playerFactor / 2);
        const totalVal = queenCount * valPerQueen;
        tricks += totalVal;
        
        reasoning.push({
          text: `${queenCount}x Q${symbol} (${isGuarded ? 'guarded' : 'unguarded'}) → value contribution ${totalVal.toFixed(2)}.`,
          type: 'side-suit-reason'
        });
      }
    });

    // --- 3. Ruffing Heuristics (Short Side-Suits + Long Spades) ---
    const longSpadeCount = Math.max(0, spades.length - 3);
    if (longSpadeCount > 0 && handSize >= 5) {
      // More players = short suits ruffed faster
      const ruffScale = Math.min(longSpadeCount, 4) * (0.45 + (players - 4) * 0.02);
      tricks += ruffScale;
      reasoning.push({
        text: `Ruffing potential with ${spades.length} Spades (${players} players scale) → adding ~${ruffScale.toFixed(2)} tricks.`,
        type: 'special-reason'
      });
    }

    if (spades.length >= 2 && handSize >= 5) {
      ['H', 'D', 'C'].forEach(s => {
        const len = state.hand[s].length;
        const name = SUIT_NAMES[s].toLowerCase();
        const symbol = SUIT_SYMBOLS[s];

        if (len === 0) {
          const voidVal = 0.5 + (players - 4) * 0.05;
          tricks += voidVal;
          reasoning.push({
            text: `Void in ${name} ${symbol} (${players} players scale) → trump power worth ~${voidVal.toFixed(2)} tricks.`,
            type: 'special-reason'
          });
        } else if (len === 1 && !state.hand[s].includes(14)) {
          const singVal = 0.25 + (players - 4) * 0.03;
          tricks += singVal;
          reasoning.push({
            text: `Singleton in ${name} ${symbol} (${players} players scale) → rapid entry to ruffing worth ~${singVal.toFixed(2)} tricks.`,
            type: 'special-reason'
          });
        }
      });
    }

    // --- 4. Micro Hand Size adjustments ---
    if (handSize === 1) {
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

        // Opponents count scaling for 1-card round
        // More players = lower odds of winning unless card is Ace
        if (activeCard < 14) {
          p = Math.max(0.05, p - (players - 4) * 0.06);
        }

        tricks = p;

        reasoning.length = 0; // Reset other reasoning
        reasoning.push({
          text: `1-card round (${players} players): ${VALUE_TO_RANK[activeCard]}${SUIT_SYMBOLS[activeSuit]} wins ~${Math.round(p * 100)}% of the time.`,
          type: 'special-reason'
        });
      }
    } else if (handSize === 2) {
      tricks = Math.min(tricks, 2.0) * 0.85; // Dampening high variance
    }

    // Rounding and Clamping
    let finalPrediction = Math.round(tricks);

    // Clamp to maximum hand size or maximum possible tricks
    finalPrediction = Math.max(0, Math.min(handSize, finalPrediction));

    // Confidence Metrics
    let confidence = 'med';
    if (handSize <= 2) {
      confidence = 'low';
    } else if (handSize >= 7) {
      confidence = 'high';
    }

    // Soften confidence if mathematically near the rounding line (use post-adjustment tricks)
    const fraction = Math.abs(tricks - Math.round(tricks));
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
    const headerSummary = $('predictionHeaderSummary');

    $('handSize').textContent = String(p.handSize);
    $('spadeCount').textContent = String(p.spadeCount);

    if (p.handSize === 0) {
      numberDiv.textContent = '—';
      circle.classList.remove('has-bid');
      
      confidence.className = 'confidence-pill low';
      confidence.textContent = 'No Bid';
      
      list.innerHTML = `<li class="empty-reason">Select cards above to calculate your expected Progressive Spades bid.</li>`;
      
      if (headerSummary) {
        headerSummary.textContent = 'No Cards Selected';
      }
      return;
    }

    numberDiv.textContent = String(p.tricks);
    circle.classList.add('has-bid');

    // Set confidence classes
    confidence.className = `confidence-pill ${p.confidence}`;
    confidence.textContent = p.confidence + ' confidence';

    // Update Collapsible Header Summary Badge
    if (headerSummary) {
      headerSummary.textContent = `${p.tricks} Trick${p.tricks !== 1 ? 's' : ''} (${p.handSize} Card${p.handSize !== 1 ? 's' : ''} • ${p.confidence} Conf)`;
    }

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

  // ---------- PHASE 2 SCOREKEEPER CALCULATIONS ENGINE ----------

  // Calculate score for a single team in a round
  function calculateRoundScore(bid, actual, rules) {
    let roundScore = 0;
    let bags = 0;

    if (rules === 'standard' && bid === 0) {
      // Nil Bidding Heuristic
      if (actual === 0) {
        roundScore = 100; // Successful Nil
      } else {
        roundScore = -100; // Failed Nil
        bags = actual; // tricks won are counted as bags
      }
    } else {
      if (actual >= bid) {
        // Successful Bid
        roundScore = (bid * 10) + (actual - bid);
        bags = (rules === 'standard') ? (actual - bid) : 0;
      } else {
        // Set (Failed Bid)
        roundScore = -(bid * 10);
        bags = 0;
      }
    }

    return { roundScore, bags };
  }

  // Recalculates all rounds from scratch to dynamically adjust standings
  function recalculateMatch() {
    const s = state.scorekeeper;
    
    // Reset standing numbers
    s.teamAScore = 0;
    s.teamBScore = 0;
    s.teamABags = 0;
    s.teamBBags = 0;

    s.rounds.forEach(r => {
      const resA = calculateRoundScore(r.bidA, r.actualA, s.rules);
      const resB = calculateRoundScore(r.bidB, r.actualB, s.rules);

      r.scoreA = resA.roundScore;
      r.bagsA = resA.bags;
      r.scoreB = resB.roundScore;
      r.bagsB = resB.bags;

      // Accumulate
      s.teamAScore += r.scoreA;
      s.teamBScore += r.scoreB;
      s.teamABags += r.bagsA;
      s.teamBBags += r.bagsB;

      // Standard Rules Bags Penalty Check (-100pts per 10 bags)
      if (s.rules === 'standard') {
        while (s.teamABags >= 10) {
          s.teamAScore -= 100;
          s.teamABags -= 10;
        }
        while (s.teamBBags >= 10) {
          s.teamBScore -= 100;
          s.teamBBags -= 10;
        }
      }
    });

    renderScoreboard();
  }

  // Sync team custom names to headings, selectors, and scoreboard table headers
  function updateUIWithTeamNames() {
    const s = state.scorekeeper;

    // Update Log Round Form Labels
    const lblA = $('labelTeamA');
    const lblB = $('labelTeamB');
    if (lblA) lblA.textContent = s.teamAName;
    if (lblB) lblB.textContent = s.teamBName;

    // Update Scorecard History Table headers
    const hdrA = $('headerTeamA');
    const hdrB = $('headerTeamB');
    const hdrScA = $('headerScoreA');
    const hdrScB = $('headerScoreB');
    
    if (hdrA) hdrA.textContent = `${s.teamAName} (Bid/Act)`;
    if (hdrB) hdrB.textContent = `${s.teamBName} (Bid/Act)`;
    if (hdrScA) hdrScA.textContent = `${s.teamAName} Score`;
    if (hdrScB) hdrScB.textContent = `${s.teamBName} Score`;
  }

  // Handle score logging submission
  function submitRound() {
    const bidAInput = $('bidTeamA');
    const actualAInput = $('actualTeamA');
    const bidBInput = $('bidTeamB');
    const actualBInput = $('actualTeamB');

    const rawBidA = bidAInput.value.trim();
    const rawActualA = actualAInput.value.trim();
    const rawBidB = bidBInput.value.trim();
    const rawActualB = actualBInput.value.trim();

    const bidA = Number(rawBidA);
    const actualA = Number(rawActualA);
    const bidB = Number(rawBidB);
    const actualB = Number(rawActualB);

    // Validation
    if (rawBidA === '' || rawActualA === '' || rawBidB === '' || rawActualB === '') {
      toast('Please fill in bids and tricks won for both teams.');
      return;
    }

    if (!Number.isInteger(bidA) || !Number.isInteger(actualA) ||
        !Number.isInteger(bidB) || !Number.isInteger(actualB)) {
      toast('Bids and tricks won must be whole numbers.');
      return;
    }

    if (bidA < 0 || actualA < 0 || bidB < 0 || actualB < 0) {
      toast('Bids and scores cannot be negative.');
      return;
    }

    const maxTricks = Math.floor(state.decks * 52 / state.players);
    if (bidA > maxTricks || actualA > maxTricks || bidB > maxTricks || actualB > maxTricks) {
      toast(`Values cannot exceed max tricks per hand (${maxTricks}).`);
      return;
    }

    if (actualA + actualB > state.decks * 13) {
      toast(`Combined tricks won (${actualA + actualB}) cannot exceed total tricks in play (${state.decks * 13}).`);
      return;
    }

    const s = state.scorekeeper;
    const nextRoundNum = s.rounds.length + 1;

    // Push into round history
    s.rounds.push({
      roundNumber: nextRoundNum,
      bidA, actualA, scoreA: 0, bagsA: 0,
      bidB, actualB, scoreB: 0, bagsB: 0
    });

    // Clear input fields
    bidAInput.value = '';
    actualAInput.value = '';
    bidBInput.value = '';
    actualBInput.value = '';

    // Recompute total scores
    recalculateMatch();
    toast(`Round ${nextRoundNum} logged.`);
  }

  // Handle Scoreboard Reset
  function resetMatch() {
    if (confirm('Are you sure you want to reset the current match scoreboard?')) {
      const s = state.scorekeeper;
      s.rounds = [];
      s.teamAName = 'Team A';
      s.teamBName = 'Team B';

      const inputA = $('teamANameInput');
      const inputB = $('teamBNameInput');
      if (inputA) inputA.value = 'Team A';
      if (inputB) inputB.value = 'Team B';

      $('bidTeamA').value = '';
      $('actualTeamA').value = '';
      $('bidTeamB').value = '';
      $('actualTeamB').value = '';

      updateUIWithTeamNames();
      recalculateMatch();
      toast('Scores reset.');
    }
  }

  // Custom Toast helper
  function toast(msg) {
    const t = document.createElement('div');
    t.className = 'toast';
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(() => {
      t.style.opacity = '0';
      setTimeout(() => t.remove(), 300);
    }, 2500);
  }

  // Renders Scorekeeper Screen
  function renderScoreboard() {
    const s = state.scorekeeper;

    // Update standing numbers
    $('scoreTeamA').textContent = String(s.teamAScore);
    $('scoreTeamB').textContent = String(s.teamBScore);

    // Dynamic bags display scaling
    const bagsAWrapper = $('bagsTeamA').parentElement;
    const bagsBWrapper = $('bagsTeamB').parentElement;

    if (s.rules === 'progressive') {
      bagsAWrapper.style.display = 'none';
      bagsBWrapper.style.display = 'none';
    } else {
      bagsAWrapper.style.display = 'inline-block';
      bagsBWrapper.style.display = 'inline-block';
      $('bagsTeamA').textContent = `${s.teamABags} / 10`;
      $('bagsTeamB').textContent = `${s.teamBBags} / 10`;
    }

    // Populate scorecard table rows
    const tbody = $('scoreboardBody');
    tbody.innerHTML = '';

    if (s.rounds.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="5" style="color: var(--text-muted); font-style: italic; padding: 20px 0;">
            No rounds recorded yet. Submit scores above!
          </td>
        </tr>
      `;
      return;
    }

    s.rounds.forEach(r => {
      const tr = document.createElement('tr');

      // Round # cell
      const tdRound = document.createElement('td');
      tdRound.textContent = `R${r.roundNumber}`;
      tr.appendChild(tdRound);

      // Team A Bid/Act cell
      const tdActA = document.createElement('td');
      tdActA.innerHTML = `Bid: <strong>${r.bidA === 0 ? 'Nil' : r.bidA}</strong> / Won: <strong>${r.actualA}</strong>`;
      tr.appendChild(tdActA);

      // Team A Score cell
      const tdScoreA = document.createElement('td');
      const winA = r.scoreA >= 0;
      tdScoreA.className = winA ? 'score-success' : 'score-fail';
      
      let scoreTextA = `${winA ? '+' : ''}${r.scoreA}`;
      if (s.rules === 'standard' && r.bagsA > 0) {
        scoreTextA += ` <span class="score-bags">(+${r.bagsA}🎒)</span>`;
      }
      tdScoreA.innerHTML = scoreTextA;
      tr.appendChild(tdScoreA);

      // Team B Bid/Act cell
      const tdActB = document.createElement('td');
      tdActB.innerHTML = `Bid: <strong>${r.bidB === 0 ? 'Nil' : r.bidB}</strong> / Won: <strong>${r.actualB}</strong>`;
      tr.appendChild(tdActB);

      // Team B Score cell
      const tdScoreB = document.createElement('td');
      const winB = r.scoreB >= 0;
      tdScoreB.className = winB ? 'score-success' : 'score-fail';
      
      let scoreTextB = `${winB ? '+' : ''}${r.scoreB}`;
      if (s.rules === 'standard' && r.bagsB > 0) {
        scoreTextB += ` <span class="score-bags">(+${r.bagsB}🎒)</span>`;
      }
      tdScoreB.innerHTML = scoreTextB;
      tr.appendChild(tdScoreB);

      tbody.appendChild(tr);
    });
  }

  // Start on content load
  document.addEventListener('DOMContentLoaded', init);
})();
