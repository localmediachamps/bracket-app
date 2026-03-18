const CHAMP_ROUNDS = ['pigtail', 'champ_r1', 'champ_qf', 'champ_sf', 'champ_finals', 'champ_3rd'];
const CONS_ROUNDS  = ['cons_r1', 'cons_r2', 'cons_r3', 'cons_r4', 'cons_sf', 'cons_finals'];

const ROUND_LABELS = {
  pigtail:      'Pigtail',
  champ_r1:     'Round 1',
  champ_qf:     'Quarters',
  champ_sf:     'Semis',
  champ_finals: 'Finals',
  champ_3rd:    '3rd Place',
  cons_r1:      'Cons R1',
  cons_r2:      'Cons R2',
  cons_r3:      'Cons R3',
  cons_r4:      'Cons R4',
  cons_sf:      'Cons Semis',
  cons_finals:  'Cons Finals',
};

function wrestlerLabel(wrestler) {
  if (!wrestler) return 'TBD';
  const seed = wrestler.seed ? `#${wrestler.seed} ` : '';
  return seed + (wrestler.name || 'Unknown');
}

function renderBracket(container, data, onPickClick) {
  const { matches = [], wrestlers_map = {}, picks_map = {} } = data;

  const champMatches = {};
  const consMatches  = {};

  for (const m of matches) {
    if (CHAMP_ROUNDS.includes(m.round_code)) {
      if (!champMatches[m.round_code]) champMatches[m.round_code] = [];
      champMatches[m.round_code].push(m);
    } else if (CONS_ROUNDS.includes(m.round_code)) {
      if (!consMatches[m.round_code]) consMatches[m.round_code] = [];
      consMatches[m.round_code].push(m);
    }
  }

  // Sort each round by match_number
  for (const key of Object.keys(champMatches)) champMatches[key].sort((a, b) => a.match_number - b.match_number);
  for (const key of Object.keys(consMatches))  consMatches[key].sort((a, b) => a.match_number - b.match_number);

  container.innerHTML = '';

  // Progress
  const totalMatches  = matches.length;
  const pickedMatches = matches.filter(m => picks_map[m.id] != null).length;
  const pct = totalMatches ? Math.round((pickedMatches / totalMatches) * 100) : 0;

  container.insertAdjacentHTML('beforeend', `
    <div class="progress-wrap">
      <div class="progress-label">${pickedMatches} / ${totalMatches} picks made</div>
      <div class="progress-track"><div class="progress-bar" style="width:${pct}%"></div></div>
    </div>
  `);

  // Championship bracket
  const champSection = document.createElement('div');
  champSection.className = 'bracket-section';
  champSection.innerHTML = '<div class="bracket-section-title">Championship Bracket</div>';
  const champRounds = document.createElement('div');
  champRounds.className = 'bracket-rounds';
  for (const round of CHAMP_ROUNDS) {
    const roundMatches = champMatches[round] || [];
    if (roundMatches.length === 0) continue;
    champRounds.appendChild(buildRoundColumn(round, roundMatches, wrestlers_map, picks_map, onPickClick));
  }
  champSection.appendChild(champRounds);
  container.appendChild(champSection);

  // Consolation toggle + bracket
  const consToggle = document.createElement('button');
  consToggle.className = 'btn btn-secondary btn-sm cons-toggle';
  consToggle.textContent = 'Show Consolation Bracket ▼';
  container.appendChild(consToggle);

  const consSection = document.createElement('div');
  consSection.className = 'bracket-section cons-section hidden';
  consSection.innerHTML = '<div class="bracket-section-title">Consolation Bracket</div>';
  const consRounds = document.createElement('div');
  consRounds.className = 'bracket-rounds';
  for (const round of CONS_ROUNDS) {
    const roundMatches = consMatches[round] || [];
    if (roundMatches.length === 0) continue;
    consRounds.appendChild(buildRoundColumn(round, roundMatches, wrestlers_map, picks_map, onPickClick));
  }
  consSection.appendChild(consRounds);
  container.appendChild(consSection);

  consToggle.addEventListener('click', () => {
    const hidden = consSection.classList.toggle('hidden');
    consToggle.textContent = hidden ? 'Show Consolation Bracket ▼' : 'Hide Consolation Bracket ▲';
  });
}

function buildRoundColumn(round, roundMatches, wrestlers_map, picks_map, onPickClick) {
  const col = document.createElement('div');
  col.className = 'bracket-round';
  col.innerHTML = `<div class="round-label">${ROUND_LABELS[round] || round}</div>`;
  const matchesWrap = document.createElement('div');
  matchesWrap.className = 'round-matches';
  for (const m of roundMatches) {
    matchesWrap.appendChild(buildMatchCard(m, wrestlers_map, picks_map, onPickClick));
  }
  col.appendChild(matchesWrap);
  return col;
}

function buildMatchCard(match, wrestlers_map, picks_map, onPickClick) {
  const card = document.createElement('div');
  card.className = 'bracket-match';
  card.dataset.matchId = match.id;

  const topId    = match.actual_top_wrestler_id;
  const bottomId = match.actual_bottom_wrestler_id;
  const pickedId = picks_map[match.id];
  const winnerId = match.actual_winner_wrestler_id;
  const done     = match.match_status === 'complete';

  function slotClasses(wId) {
    const classes = ['wrestler-slot'];
    if (!wId) { classes.push('tbd'); return classes.join(' '); }
    if (pickedId === wId) {
      if (done && winnerId != null) {
        classes.push(winnerId === wId ? 'correct' : 'incorrect');
      } else {
        classes.push('selected');
      }
    }
    if (done && winnerId === wId) classes.push('winner');
    return classes.join(' ');
  }

  const topW    = topId    ? wrestlers_map[topId]    : null;
  const bottomW = bottomId ? wrestlers_map[bottomId] : null;

  card.innerHTML = `
    <div class="${slotClasses(topId)}"    data-wrestler-id="${topId    || ''}">${wrestlerLabel(topW)}</div>
    <div class="${slotClasses(bottomId)}" data-wrestler-id="${bottomId || ''}">${wrestlerLabel(bottomW)}</div>
  `;

  card.querySelectorAll('.wrestler-slot:not(.tbd)').forEach(slot => {
    slot.addEventListener('click', () => {
      const wId = parseInt(slot.dataset.wrestlerId, 10);
      if (wId && onPickClick) onPickClick(match.id, wId);
    });
  });

  return card;
}
