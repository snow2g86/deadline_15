// party-select.js — 파티 편성 + 장비 관리 통합 페이지
// 공통 모듈에서 공유 함수 로드

// ── 스킬 정보 포맷팅 ──────────────────────
function formatPartyCharSkills(ch) {
  var skills = getCharSkills(ch.cls);
  if (!skills.length) return '';
  var parts = [];
  skills.forEach(function(sk) {
    var lv = getCharSkillLv(ch, sk.id);
    if (lv > 0) parts.push('Lv' + lv + '. ' + t('skills.' + sk.id));
  });
  return parts.length ? parts.join(' | ') : '';
}

// ── 전역 포션/공성 아이템 로드/저장 ──────────────
function loadGlobalBattleItems() {
  try {
    var data = JSON.parse(localStorage.getItem('game_battle_items')) || {};
    _globalBattlePotions = data.potions || [];
    _globalSiegeItems = data.sieges || [];
  } catch (_) {}
}

function saveGlobalBattleItems() {
  try {
    var data = { potions: _globalBattlePotions, sieges: _globalSiegeItems };
    localStorage.setItem('game_battle_items', JSON.stringify(data));
  } catch (_) {}
}

// ── 페이지 상태 ──────────────────────────
var _party = [];
var _cStage = null;
var _practiceMode = false;
var _pFilter = 'all';
var _activePageTab = localStorage.getItem('ps_active_tab') || 'party';

// ── 장비 상태 ──────────────────────────
var _selUid = null;
var _invFilter = 'all';
var _eqFilter = 'all';
var _gold = 0;

// ── 전체 아군 공유 아이템 ──────────────
var _globalBattlePotions = [];  // 전투 포션 ID 배열
var _globalSiegeItems = [];      // 공성 아이템 ID 배열


// ── 골드 UI ─────────────────────────────
function updatePageGold() {
  var el = document.getElementById('ps-gold-val');
  if (el) el.textContent = loadGold().toLocaleString();
}

// ── 출격 버튼 활성화 상태 ──────────────────
function updateStartButtonVisibility() {
  var psStartBtn = document.getElementById('ps-start');
  if (psStartBtn) {
    // localStorage에서 출격 가능 여부 확인
    var canEnable = localStorage.getItem('ps_can_start') === 'true';
    psStartBtn.disabled = !canEnable;
    // 비활성화되면 숨김, 활성화되면 표시
    psStartBtn.style.display = canEnable ? '' : 'none';
  }
}

// ── 탭 전환 ─────────────────────────────
function switchPageTab(tab) {
  _activePageTab = tab;
  // localStorage에 현재 탭 저장
  localStorage.setItem('ps_active_tab', tab);

  var tabs = document.querySelectorAll('.game-tabs .game-tab');
  tabs.forEach(function(btn) {
    btn.classList.toggle('active', btn.getAttribute('data-ptab') === tab);
  });
  document.getElementById('section-party').style.display = tab === 'party' ? '' : 'none';
  document.getElementById('section-equip').style.display = tab === 'equip' ? '' : 'none';
  document.getElementById('section-item').style.display = tab === 'item' ? '' : 'none';
  document.getElementById('section-enhance').style.display = tab === 'enhance' ? '' : 'none';

  // 파티 탭이 아니면 출격 버튼 숨기기
  var psStartBtn = document.getElementById('ps-start');
  if (psStartBtn) {
    psStartBtn.style.display = tab === 'party' ? '' : 'none';
  }

  if (tab === 'equip') {
    _gold = loadGold();
    eqRenderAll();
  }
  if (tab === 'item') {
    renderItemTab();
  }
  if (tab === 'enhance') {
    _gold = loadGold();
    renderEnhanceList();
  }
  updatePageGold();
}


// ── 뒤로가기 ────────────────────────────
function partyBack() {
  // 출격 버튼 비활성화
  localStorage.setItem('ps_can_start', 'false');
  location.href = 'index.html';
}

// ── 출격 확인 ────────────────────────────
function confirmP() {
  var activeParty = getActiveParty();
  if (activeParty.length < MIN_P) return;
  saveNav({ cStage: _cStage, party: activeParty, practiceMode: _practiceMode });
  location.href = 'battle.html';
}

// ── 캐릭터 방출 ─────────────────────────
function releaseChar(uid) {
  uid = +uid;
  var ch = getChar(uid);
  if (!ch) return;
  var roster = getRoster();
  var alive = roster.chars.filter(function(c) { return !c.dead; });
  if (alive.length <= 5) {
    showAlert(t('messages.minimum_characters'));
    return;
  }
  if (_party.indexOf(uid) !== -1) {
    showAlert(t('messages.cannot_release_party'));
    return;
  }
  var price = 30 + ch.lv * 5;
  var grade = potGrade(ch);
  var d = JAB[ch.cls];
  var names = t('character.names');
  var charName = ch.customName || names[ch.nameId] || d.icon;
  showConfirm(
    d.icon + ' ' + charName + ' (Lv.' + ch.lv + ' ' + grade + t('class_change.grade_suffix') + ')\n\n' +
    t('messages.confirm_release', { gold: price }),
    function() {
      var roster = getRoster();
      roster.chars = roster.chars.filter(function(c) { return c.uid !== uid; });
      saveRoster(roster);
      var gold = loadGold();
      gold += price;
      saveGold(gold);
      updatePageGold();
      renderPartySlots();
    }
  );
}

// ── 이름 변경 ─────────────────────────────
function renameChar(uid) {
  uid = +uid;
  var ch = getChar(uid);
  if (!ch) return;
  var names = t('character.names');
  var curName = ch.customName || names[ch.nameId] || '';
  showPrompt(t('party.rename_prompt'), curName, function(val) {
    var roster = getRoster();
    var target = roster.chars.find(function(c) { return c.uid === uid; });
    if (!target) return;
    if (val && val !== names[target.nameId]) {
      target.customName = val;
    } else {
      delete target.customName;
    }
    saveRoster(roster);
    renderParty();
  });
}

// ── 필터 변경 ────────────────────────────
function filterBy(key) {
  _pFilter = key;
  renderParty();
}

// ═══════════════════════════════════════════
// 다중 파티 시스템 (Multi-Party System)
// ═══════════════════════════════════════════

// ── 전역 상태 ──────────────────────────────
var _parties = null;          // 다중 파티 데이터
var _currentPartyId = null;   // 현재 선택된 파티 ID
var _unitModalSlotIdx = null; // 모달에서 선택할 슬롯 인덱스

// ── 파티 탭 렌더링 ────────────────────────
function renderPartyTabs() {
  var container = document.getElementById('party-tabs');
  if (!container || !_parties) return;

  container.innerHTML = '';

  _parties.parties.forEach(function(party) {
    var btn = document.createElement('button');
    btn.className = 'party-tab' + (_currentPartyId === party.id ? ' active' : '');
    btn.textContent = party.name;
    btn.onclick = function() {
      setActiveParty(party.id);
    };
    container.appendChild(btn);
  });
}

// ── 파티 슬롯 렌더링 ────────────────────────
function renderPartySlots() {
  var container = document.getElementById('party-slots');
  if (!container || !_parties) return;

  var activeParty = _parties.parties.find(function(p) { return p.id === _currentPartyId; });
  if (!activeParty) return;

  container.innerHTML = '';
  var roster = getRoster();

  // 파티 슬롯 그리드 생성
  var slotRow = document.createElement('div');
  slotRow.className = 'party-slot-row';

  activeParty.slots.forEach(function(uid, idx) {
    var slot = document.createElement('div');
    slot.className = 'party-slot' + (uid ? ' filled' : ' empty');

    if (uid) {
      var ch = roster.chars.find(function(c) { return c.uid === uid; });
      if (ch) {
        var charName = ch.customName || t('character.names')[ch.nameId] || JAB[ch.cls].icon;
        var bonus = calcEquipBonus(ch);
        var skills = getCharSkills(ch.cls);
        var grade = potGrade(ch);
        var gradeColor = GRADE_COLORS[grade] || '#9ca3af';

        // 1줄: 아이콘 + 기본정보 + 제거버튼
        var header = document.createElement('div');
        header.className = 'party-slot-header';
        header.innerHTML =
          '<div class="party-slot-icon">' + charSprite(ch.cls, 40, ch.gender) + '</div>' +
          '<div class="party-slot-info">' +
            '<div class="party-slot-level"><span class="ps-level-text">Lv.' + ch.lv + '</span> <span class="sb-cls-label">' + t('classes.' + ch.cls) + '</span></div>' +
            '<div class="party-slot-name">' + charName + '<span class="ps-grade-text" style="color:' + gradeColor + '">' + grade + '</span></div>' +
          '</div>';
        slot.appendChild(header);

        // 2줄: 스탯 + 스킬
        var footer = document.createElement('div');
        footer.className = 'party-slot-footer';

        var statsHtml = '<div class="party-slot-stats">' +
          '<span class="ps-stat-item">HP ' + ch.hp + (bonus.hp > 0 ? '<span class="bonus">+' + bonus.hp + '</span>' : '') + '</span>' +
          '<span class="ps-stat-item">ATK ' + ch.atk + (bonus.atk > 0 ? '<span class="bonus">+' + bonus.atk + '</span>' : '') + '</span>' +
          '<span class="ps-stat-item">DEF ' + ch.def + (bonus.def > 0 ? '<span class="bonus">+' + bonus.def + '</span>' : '') + '</span>' +
        '</div>';

        var skillsHtml = '<div class="party-slot-skills">';
        if (skills.length > 0) {
          skills.forEach(function(sk) {
            var lv = getCharSkillLv(ch, sk.id);
            if (lv > 0) {
              skillsHtml += '<span class="ps-skill" title="Lv' + lv + '">' + skillIcon(sk.id, 16) + '</span>';
            }
          });
        } else {
          skillsHtml += '<span class="ps-skill-none">-</span>';
        }
        skillsHtml += '</div>';

        footer.innerHTML = statsHtml + skillsHtml;
        slot.appendChild(footer);

        // 제거 버튼
        var removeBtn = document.createElement('button');
        removeBtn.className = 'party-slot-remove';
        removeBtn.textContent = '✕';
        removeBtn.onclick = function(e) {
          e.stopPropagation();
          removeFromSlot(idx);
        };
        slot.appendChild(removeBtn);
      }
    } else {
      slot.innerHTML = '<div class="party-slot-content">+</div>';
    }

    slot.onclick = function() {
      openUnitModal(idx);
    };

    slotRow.appendChild(slot);
  });

  container.appendChild(slotRow);

  // 파티 카운터 업데이트
  var counter = document.getElementById('ps-counter');
  var count = activeParty.slots.filter(function(uid) { return uid !== null; }).length;
  if (counter) {
    var readyClass = count >= MIN_P ? ' ready' : '';
    counter.textContent = count + ' / 5';
    counter.className = 'ps-counter' + readyClass;
  }

  // 출격 버튼 활성/비활성화 업데이트
  var psStartBtn = document.getElementById('ps-start');
  if (psStartBtn) {
    var canStart = count >= MIN_P && localStorage.getItem('ps_can_start') === 'true';
    psStartBtn.disabled = !canStart;
    // 조건을 만족하지 않으면 숨김
    psStartBtn.style.display = (count >= MIN_P && localStorage.getItem('ps_can_start') === 'true') ? '' : 'none';
  }
}

// ── 활성 파티 변경 ────────────────────────
function setActiveParty(partyId) {
  if (!_parties) return;
  _currentPartyId = partyId;
  _parties.activePartyId = partyId;
  saveParties(_parties);
  renderPartyTabs();
  renderPartySlots();
  updateStartButtonVisibility();
}

// ── 파티 추가 ────────────────────────────
function addParty() {
  if (!_parties || _parties.parties.length >= 5) return;
  var newId = _parties.nextPartyId++;
  _parties.parties.push({
    id: newId,
    name: '파티 ' + newId,
    slots: [null, null, null, null, null]
  });
  saveParties(_parties);
  renderPartyTabs();
  setActiveParty(newId);
}

// ── 파티 삭제 ────────────────────────────
function deleteParty(partyId) {
  if (!_parties || _parties.parties.length <= 2) return;
  _parties.parties = _parties.parties.filter(function(p) { return p.id !== partyId; });
  if (_currentPartyId === partyId) {
    _currentPartyId = _parties.parties[0].id;
    _parties.activePartyId = _currentPartyId;
  }
  saveParties(_parties);
  renderPartyTabs();
  renderPartySlots();
}

// ── 슬롯에서 유닛 제거 ────────────────────
function removeFromSlot(slotIdx) {
  if (!_parties) return;
  var activeParty = _parties.parties.find(function(p) { return p.id === _currentPartyId; });
  if (activeParty) {
    activeParty.slots[slotIdx] = null;
    saveParties(_parties);
    renderPartySlots();
  }
}

// ── 유닛 선택 모달 열기 ────────────────────
function openUnitModal(slotIdx) {
  _unitModalSlotIdx = slotIdx;
  var modal = document.getElementById('unit-select-modal-overlay');
  if (modal) {
    modal.style.display = 'flex';
    renderUnitFilterTabs();
    renderUnitCards('all');
  }
}

// ── 유닛 선택 모달 닫기 ────────────────────
function closeUnitModal() {
  var modal = document.getElementById('unit-select-modal-overlay');
  if (modal) modal.style.display = 'none';
  _unitModalSlotIdx = null;
}

// ── 모달 필터 탭 렌더링 ────────────────────
function renderUnitFilterTabs() {
  var container = document.getElementById('unit-filter-tabs');
  if (!container) return;

  // 소유한 캐릭터들의 직업군 수집
  var roster = getRoster();
  var existingGroups = new Set();

  roster.chars.forEach(function(ch) {
    if (!ch.dead && !ch.cls.startsWith('summon_')) {
      var group = CLASS_GROUP_MAP[ch.cls];
      if (group) existingGroups.add(group);
    }
  });

  container.innerHTML = '';

  // "전체" 필터 먼저 추가
  var allBtn = document.createElement('button');
  allBtn.className = 'unit-filter-tab' + (_pFilter === 'all' ? ' active' : '');
  allBtn.textContent = t('common.all');
  allBtn.onclick = function() {
    _pFilter = 'all';
    renderUnitCards('all');
    container.querySelectorAll('.unit-filter-tab').forEach(function(b) {
      b.classList.remove('active');
    });
    allBtn.classList.add('active');
  };
  container.appendChild(allBtn);

  // 직업군별 필터 추가 (고정 순서: beginner, melee, ranged, support)
  var groupOrder = ['beginner', 'melee', 'ranged', 'support'];
  groupOrder.forEach(function(groupKey) {
    if (!existingGroups.has(groupKey)) return; // 소유한 직업이 없으면 스킵

    var btn = document.createElement('button');
    var filterKey = 'group_' + groupKey;
    btn.className = 'unit-filter-tab' + (_pFilter === filterKey ? ' active' : '');
    btn.textContent = t('group.' + groupKey);
    btn.onclick = function() {
      _pFilter = filterKey;
      renderUnitCards(filterKey);
      container.querySelectorAll('.unit-filter-tab').forEach(function(b) {
        b.classList.remove('active');
      });
      btn.classList.add('active');
    };
    container.appendChild(btn);
  });
}

// ── 모달 유닛 카드 렌더링 ────────────────────
function renderUnitCards(filter) {
  var container = document.getElementById('unit-cards-grid');
  if (!container || !_parties) return;

  var roster = getRoster();
  var activeParty = _parties.parties.find(function(p) { return p.id === _currentPartyId; });
  if (!activeParty) return;

  var inv = loadInventory();  // 장비 목록 미리 로드
  var alive = roster.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_'); });

  // 필터링
  if (filter !== 'all') {
    if (filter.startsWith('group_')) {
      var groupKey = filter.replace('group_', '');
      alive = alive.filter(function(c) { return CLASS_GROUP_MAP[c.cls] === groupKey; });
    } else if (filter.startsWith('role_')) {
      var role = filter.replace('role_', '');
      alive = alive.filter(function(c) { return ROLE_MAP[c.cls] === role; });
    } else if (filter.startsWith('cls_')) {
      var cls = filter.replace('cls_', '');
      alive = alive.filter(function(c) { return c.cls === cls; });
    }
  }

  // 정렬: 파티원 우선 → 레벨 내림차순
  var inPartyIds = new Set(activeParty.slots.filter(function(uid) { return uid; }));
  alive.sort(function(a, b) {
    var aInParty = inPartyIds.has(a.uid) ? 1 : 0;
    var bInParty = inPartyIds.has(b.uid) ? 1 : 0;
    if (bInParty !== aInParty) return bInParty - aInParty;
    return b.lv - a.lv;
  });

  container.innerHTML = '';

  // 필터 결과가 없을 때
  if (alive.length === 0) {
    var emptyMsg = document.createElement('div');
    emptyMsg.className = 'unit-cards-empty';
    emptyMsg.textContent = t('party.no_available_chars');
    container.appendChild(emptyMsg);
    return;
  }

  alive.forEach(function(ch) {
    var card = document.createElement('div');
    var isInParty = inPartyIds.has(ch.uid);
    card.className = 'unit-card' + (isInParty ? ' in-party' : '');

    var grade = potGrade(ch);
    var bonus = calcEquipBonus(ch);
    var skills = getCharSkills(ch.cls);

    // 등급별 색상
    var gradeColor = GRADE_COLORS[grade] || '#9ca3af';
    var gradeBg = grade === 'S' ? 'rgba(240,192,64,.15)' :
                  grade === 'A' ? 'rgba(96,165,250,.15)' :
                  grade === 'B' ? 'rgba(74,222,128,.15)' :
                  'rgba(156,163,175,.15)';

    var html = '<div class="unit-card-header">' +
      '<div class="unit-card-icon">' +
        charSprite(ch.cls, 60, ch.gender) +
        '<div class="unit-card-cls-icon">' + clsIcon(ch.cls, 20) + '</div>' +
      '</div>' +
      '<div class="unit-card-grade" style="background:' + gradeBg + '; border-color:' + gradeColor + '; color:' + gradeColor + ';">' + grade + '</div>' +
    '</div>';

    html += '<div class="unit-card-meta">' +
      '<div class="unit-card-level-cls">Lv.' + ch.lv + ' <span class="sb-cls-label">' + t('classes.' + ch.cls) + '</span></div>' +
      '<div class="unit-card-name">' + (ch.customName || t('character.names.' + ch.nameId)) + '</div>' +
    '</div>';

    html += '<div class="unit-card-stats">' +
      '<div class="unit-card-stat">' +
        '<span class="unit-card-stat-label">HP:</span>' +
        '<span class="unit-card-stat-value">' + ch.hp +
        (bonus.hp > 0 ? '<span class="unit-card-stat-bonus">+' + bonus.hp + '</span>' : '') +
        (ch.pot && ch.pot.hp ? '<span class="unit-card-stat-potential">(+' + ch.pot.hp + ')</span>' : '') +
        '</span>' +
      '</div>' +
      '<div class="unit-card-stat">' +
        '<span class="unit-card-stat-label">ATK:</span>' +
        '<span class="unit-card-stat-value">' + ch.atk +
        (bonus.atk > 0 ? '<span class="unit-card-stat-bonus">+' + bonus.atk + '</span>' : '') +
        (ch.pot && ch.pot.atk ? '<span class="unit-card-stat-potential">(+' + ch.pot.atk + ')</span>' : '') +
        '</span>' +
      '</div>' +
      '<div class="unit-card-stat">' +
        '<span class="unit-card-stat-label">DEF:</span>' +
        '<span class="unit-card-stat-value">' + ch.def +
        (bonus.def > 0 ? '<span class="unit-card-stat-bonus">+' + bonus.def + '</span>' : '') +
        (ch.pot && ch.pot.def ? '<span class="unit-card-stat-potential">(+' + ch.pot.def + ')</span>' : '') +
        '</span>' +
      '</div>' +
    '</div>';

    // 장비 슬롯
    html += '<div class="unit-card-equips">';
    ['weapon', 'offhand', 'helmet', 'armor', 'boots', 'necklace', 'earring', 'ring'].forEach(function(slot) {
      var eqId = (ch.equip && ch.equip[slot]) ? ch.equip[slot] : null;
      var eq = null;
      if (eqId) {
        eq = inv.find(function(item) { return item.eid === eqId && item.type === 'equip'; });
      }
      if (eq) {
        html += '<div class="unit-card-equip-slot filled" data-rarity="' + eq.rarity + '">' +
          (eq.rarity.charAt(0).toUpperCase()) +
          '<span class="unit-card-equip-lv">+' + (eq.enhanceLv || 0) + '</span>' +
        '</div>';
      } else {
        html += '<div class="unit-card-equip-slot"></div>';
      }
    });
    html += '</div>';

    // 스킬
    if (skills.length > 0) {
      html += '<div class="unit-card-skills">';
      skills.forEach(function(sk) {
        var lv = getCharSkillLv(ch, sk.id);
        if (lv > 0) {
          html += '<span class="unit-card-skill">' + skillIcon(sk.id, 20) +
            '<span class="unit-card-skill-lv">' + lv + '</span></span>';
        }
      });
      html += '</div>';
    }

    card.innerHTML = html;
    card.onclick = function() {
      selectUnitForSlot(ch.uid);
    };

    container.appendChild(card);
  });
}

// ── 유닛 선택 및 슬롯 할당 ────────────────────
function selectUnitForSlot(uid) {
  if (_unitModalSlotIdx === null || !_parties) return;

  var activeParty = _parties.parties.find(function(p) { return p.id === _currentPartyId; });
  if (!activeParty) return;

  // 이미 다른 슬롯에 있는 유닛이면 제거
  for (var i = 0; i < activeParty.slots.length; i++) {
    if (activeParty.slots[i] === uid) {
      activeParty.slots[i] = null;
      break;
    }
  }

  // 새 슬롯에 할당
  activeParty.slots[_unitModalSlotIdx] = uid;
  saveParties(_parties);
  closeUnitModal();
  renderPartySlots();
}

// ── 파티 렌더링 (legacy.js rP() 대체) ────
// ── 파티 렌더링 (카드 그리드 방식) ────
function renderParty() {
  var roster = getRoster();
  var inParty = {};
  _party.forEach(function(uid) { inParty[uid] = true; });
  var alive = roster.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_'); });

  // ── 탭 렌더링 (변경 없음) ──
  var tabEl = document.getElementById('ps-tabs');
  if (tabEl) {
    var ownedRoles = {};
    var ownedClasses = {};
    alive.forEach(function(c) {
      var role = ROLE_MAP[c.cls];
      if (role) ownedRoles[role] = true;
      ownedClasses[c.cls] = true;
    });
    tabEl.innerHTML = '';
    // 전체 탭
    var allBtn = document.createElement('button');
    allBtn.className = 'ps-tab' + (_pFilter === 'all' ? ' active' : '');
    allBtn.textContent = t('party.filter_all');
    allBtn.onclick = function() { filterBy('all'); };
    tabEl.appendChild(allBtn);
    // 역할 탭
    ['melee', 'ranged', 'healer'].forEach(function(r) {
      if (!ownedRoles[r]) return;
      var btn = document.createElement('button');
      btn.className = 'ps-tab' + (_pFilter === 'role_' + r ? ' active' : '');
      btn.textContent = t(ROLE_I18N[r]);
      btn.onclick = function() { filterBy('role_' + r); };
      tabEl.appendChild(btn);
    });
    // 클래스 탭
    Object.keys(JAB).forEach(function(cls) {
      if (!ownedClasses[cls] || cls.startsWith('summon_')) return;
      var btn = document.createElement('button');
      btn.className = 'ps-tab' + (_pFilter === 'cls_' + cls ? ' active' : '');
      btn.textContent = t('classes.' + cls);
      btn.onclick = function() { filterBy('cls_' + cls); };
      tabEl.appendChild(btn);
    });
  }

  // ── 필터링 (변경 없음) ──
  var filtered = alive;
  if (_pFilter.startsWith('role_')) {
    var role = _pFilter.slice(5);
    filtered = alive.filter(function(c) { return ROLE_MAP[c.cls] === role; });
  } else if (_pFilter.startsWith('cls_')) {
    var cls = _pFilter.slice(4);
    filtered = alive.filter(function(c) { return c.cls === cls; });
  }

  // ── 정렬: 파티원(레벨순) → 클랜원(클래스→레벨→이름순) ──
  var clsOrder = Object.keys(JAB);
  var names = t('character.names');
  filtered.sort(function(a, b) {
    // 파티원을 먼저 표시
    var aInParty = inParty[a.uid] ? 1 : 0;
    var bInParty = inParty[b.uid] ? 1 : 0;
    if (bInParty !== aInParty) return bInParty - aInParty;
    
    // 파티원 내에서는 레벨 내림차순
    if (aInParty && bInParty) {
      if (b.lv !== a.lv) return b.lv - a.lv;
    }
    
    // 클랜원 내에서는 클래스 → 레벨 → 이름
    var ci = clsOrder.indexOf(a.cls) - clsOrder.indexOf(b.cls);
    if (ci !== 0) return ci;
    if (b.lv !== a.lv) return b.lv - a.lv;
    var aName = a.customName || names[a.nameId] || '';
    var bName = b.customName || names[b.nameId] || '';
    return aName.localeCompare(bName);
  });

  // ── 카드 그리드 렌더링 (NEW) ──
  var grid = document.getElementById('ps-chars');
  if (!grid) return;
  grid.innerHTML = '';
  
  filtered.forEach(function(ch) {
    var isInParty = !!inParty[ch.uid];
    var d = JAB[ch.cls];
    var grade = potGrade(ch);
    var gClr = grade === 'S' ? '#f0c040' : 
                grade === 'A' ? '#60a5fa' : 
                grade === 'B' ? '#4ade80' : '#9ca3af';
    
    var atMax = ch.lv >= MAX_LEVEL;
    var expNeed = atMax ? 1 : expForLevel(ch.lv);
    var expPct = atMax ? 100 : Math.min(100, Math.round(((ch.exp || 0) / expNeed) * 100));
    
    var charName = ch.customName || names[ch.nameId] || d.icon;
    
    // 장비 보너스
    if (!ch.equip) ch.equip = {
      weapon:null, offhand:null, helmet:null, armor:null, 
      boots:null, necklace:null, earring:null, ring:null
    };
    var eqB = typeof calcEquipBonus === 'function' ? 
              calcEquipBonus(ch) : {hp:0, atk:0, def:0, move:0, range:0};
    
    // 스킬 정보
    var skillInfo = formatPartyCharSkills(ch);
    
    // 파티 순번 찾기
    var partyIndex = -1;
    if (isInParty) {
      partyIndex = _party.indexOf(ch.uid);
    }
    
    // 카드 생성
    var card = document.createElement('div');
    card.className = 'ps-char-card' + (isInParty ? ' in-party' : '');
    
    const iconSize = (ch.cls === 'brawler' || ch.cls === 'assassin') ? 51 : 60;
    
    var html = '';
    
    // 파티 배지 (파티원만)
    if (isInParty) {
      html += '<div class="ps-party-badge">' +
              '<span>' + (partyIndex + 1) + '</span>✓</div>';
    }
    
    // 캐릭터 아이콘 + 등급
    html += '<div class="ps-char-icon">' + 
            charSprite(ch.cls, iconSize, ch.gender) +
            '<span class="ps-grade-badge" style="color:' + gClr + ';border-color:' + gClr + '">' + 
            grade + '</span></div>';
    
    // 캐릭터 정보
    html += '<div class="ps-char-info">';
    
    // 레벨 + 클래스
    html += '<div class="ps-char-meta">' +
            '<span class="ps-char-level">Lv.' + ch.lv + '</span>' +
            '<span class="ps-char-cls">' + t('classes.' + ch.cls) + '</span>' +
            '</div>';
    
    // 이름 + 이름변경 버튼
    html += '<div class="ps-char-name">' +
            '<span>' + charName + '</span>' +
            '<button class="ps-rename-btn" onclick="event.stopPropagation();renameChar(' + ch.uid + ')">✎</button>' +
            '</div>';
    
    // 스탯 (콤팩트)
    html += '<div class="ps-char-stats">' +
            'HP <b>' + ch.hp + '</b>' + (eqB.hp ? '<span class="eq-bonus">+' + eqB.hp + '</span>' : '') + ' ' +
            'ATK <b>' + ch.atk + '</b>' + (eqB.atk ? '<span class="eq-bonus">+' + eqB.atk + '</span>' : '') + ' ' +
            'DEF <b>' + ch.def + '</b>' + (eqB.def ? '<span class="eq-bonus">+' + eqB.def + '</span>' : '') +
            '</div>';
    
    // 잠재력
    html += '<div class="ps-char-potential">' +
            t('party.potential_stats', {
              hp: ch.pot.hp, 
              atk: ch.pot.atk, 
              def: ch.pot.def
            }) + '</div>';
    
    // EXP 바
    html += '<div class="ps-char-exp">' +
            '<div class="ps-char-exp-fill" style="width:' + expPct + '%"></div>' +
            '</div>';
    
    // 스킬 (있으면)
    if (skillInfo) {
      html += '<div class="ps-char-skills">' + skillInfo + '</div>';
    }
    
    html += '</div>'; // .ps-char-info
    
    // 방출 버튼 (파티원 제외)
    if (!isInParty) {
      html += '<button class="ps-release-btn" onclick="event.stopPropagation();releaseChar(' + ch.uid + ')">' +
              t('party.release') + '</button>';
    }
    
    card.innerHTML = html;
    
    // 카드 클릭: 파티 추가/제거
    card.onclick = (function(chUid, wasSel) {
      return function() {
        if (wasSel) {
          _party = _party.filter(function(u) { return u !== chUid; });
        } else if (_party.length < MAX_P) {
          _party.push(chUid);
        }
        renderPartySlots();
      };
    })(ch.uid, isInParty);
    
    grid.appendChild(card);
  });

  // ── 카운터 & 출격 버튼 업데이트 ──
  var n = _party.length;
  var counterEl = document.getElementById('ps-counter');
  if (counterEl) {
    counterEl.textContent = n + ' / ' + MAX_P;
    counterEl.className = 'ps-counter' + (n >= MIN_P ? ' ready' : '');
  }
  
  var startBtn = document.getElementById('ps-start');
  if (_cStage) {
    startBtn.textContent = t('party.start_battle');
    startBtn.disabled = n < MIN_P;
    startBtn.style.display = '';
  } else {
    startBtn.style.display = 'none';
  }

  // 로스터 & 파티 저장
  saveParty(_party);
}

// ══════════════════════════════════════════════
// ── 장비 관리 (equip.js 병합) ────────────────
// ══════════════════════════════════════════════


// ── 장비 탭 필터 탭 렌더링 ────────────────────
function renderEquipFilterTabs() {
  var container = document.getElementById('eq-filter-tabs');
  if (!container) return;

  // 소유한 캐릭터들의 직업군 수집
  var roster = getRoster();
  var existingGroups = new Set();

  roster.chars.forEach(function(ch) {
    if (!ch.dead && !ch.cls.startsWith('summon_')) {
      var group = CLASS_GROUP_MAP[ch.cls];
      if (group) existingGroups.add(group);
    }
  });

  container.innerHTML = '';

  // "전체" 필터 먼저 추가
  var allBtn = document.createElement('button');
  allBtn.className = 'eq-filter-tab' + (_eqFilter === 'all' ? ' active' : '');
  allBtn.textContent = t('common.all');
  allBtn.onclick = function() {
    _eqFilter = 'all';
    renderChars();
    container.querySelectorAll('.eq-filter-tab').forEach(function(b) {
      b.classList.remove('active');
    });
    allBtn.classList.add('active');
  };
  container.appendChild(allBtn);

  // 직업군별 필터 추가 (고정 순서: beginner, melee, ranged, support)
  var groupOrder = ['beginner', 'melee', 'ranged', 'support'];
  groupOrder.forEach(function(groupKey) {
    if (!existingGroups.has(groupKey)) return; // 소유한 직업이 없으면 스킵

    var btn = document.createElement('button');
    var filterKey = 'group_' + groupKey;
    btn.className = 'eq-filter-tab' + (_eqFilter === filterKey ? ' active' : '');
    btn.textContent = t('group.' + groupKey);
    btn.onclick = function() {
      _eqFilter = filterKey;
      renderChars();
      container.querySelectorAll('.eq-filter-tab').forEach(function(b) {
        b.classList.remove('active');
      });
      btn.classList.add('active');
    };
    container.appendChild(btn);
  });
}

// ── Character card grid ──
function renderChars() {
  var el = document.getElementById('eq-chars');
  if (!el) return;
  el.innerHTML = '';

  var roster = getRoster();
  var alive = roster.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_'); });
  var names = t('character.names');
  var party = loadParty();
  var partySet = {};
  party.forEach(function(uid) { partySet[uid] = true; });

  // 정렬: 파티원(레벨 높은 순) → 클랜원(레벨 높은 순)
  alive.sort(function(a, b) {
    var aInParty = partySet[a.uid] ? 1 : 0;
    var bInParty = partySet[b.uid] ? 1 : 0;
    if (bInParty !== aInParty) return bInParty - aInParty;
    return b.lv - a.lv;
  });

  // 필터링
  if (_eqFilter !== 'all') {
    if (_eqFilter.startsWith('group_')) {
      var groupKey = _eqFilter.replace('group_', '');
      alive = alive.filter(function(c) { return CLASS_GROUP_MAP[c.cls] === groupKey; });
    } else if (_eqFilter.startsWith('cls_')) {
      var cls = _eqFilter.replace('cls_', '');
      alive = alive.filter(function(c) { return c.cls === cls; });
    }
  }

  var inv = loadInventory();
  var invEquips = inv.filter(function(it) { return it.type === 'equip' && !it.equipped; });

  alive.forEach(function(ch) {
    var d = JAB[ch.cls];
    var charName = ch.customName || names[ch.nameId] || d.icon;
    var isInParty = !!partySet[ch.uid];

    var card = document.createElement('div');
    card.className = 'unit-card' + (_selUid === ch.uid ? ' active' : '');

    var grade = potGrade(ch);
    var bonus = calcEquipBonus(ch);
    var skills = getCharSkills(ch.cls);

    // 등급별 색상
    var gradeColor = GRADE_COLORS[grade] || '#9ca3af';
    var gradeBg = grade === 'S' ? 'rgba(240,192,64,.15)' :
                  grade === 'A' ? 'rgba(96,165,250,.15)' :
                  grade === 'B' ? 'rgba(74,222,128,.15)' :
                  'rgba(156,163,175,.15)';

    var html = '';

    // 파티원 배지
    if (isInParty) {
      html += '<div class="eq-char-badge">' + t('equip.party_member') + '</div>';
    }

    // 헤더: 아이콘 + 등급
    html += '<div class="unit-card-header">' +
      '<div class="unit-card-icon">' +
        charSprite(ch.cls, 60, ch.gender) +
        '<div class="unit-card-cls-icon">' + clsIcon(ch.cls, 20) + '</div>' +
      '</div>' +
      '<div class="unit-card-grade" style="background:' + gradeBg + '; border-color:' + gradeColor + '; color:' + gradeColor + ';">' + grade + '</div>' +
    '</div>';

    // 메타: 레벨 + 클래스 + 이름
    html += '<div class="unit-card-meta">' +
      '<div class="unit-card-level-cls">Lv.' + ch.lv + ' <span class="sb-cls-label">' + t('classes.' + ch.cls) + '</span></div>' +
      '<div class="unit-card-name">' + charName + '</div>' +
    '</div>';

    // 스탯: HP/ATK/DEF + 보너스 + 잠재력
    html += '<div class="unit-card-stats">' +
      '<div class="unit-card-stat">' +
        '<span class="unit-card-stat-label">HP:</span>' +
        '<span class="unit-card-stat-value">' + ch.hp +
        (bonus.hp > 0 ? '<span class="unit-card-stat-bonus">+' + bonus.hp + '</span>' : '') +
        (ch.pot && ch.pot.hp ? '<span class="unit-card-stat-potential">(+' + ch.pot.hp + ')</span>' : '') +
        '</span>' +
      '</div>' +
      '<div class="unit-card-stat">' +
        '<span class="unit-card-stat-label">ATK:</span>' +
        '<span class="unit-card-stat-value">' + ch.atk +
        (bonus.atk > 0 ? '<span class="unit-card-stat-bonus">+' + bonus.atk + '</span>' : '') +
        (ch.pot && ch.pot.atk ? '<span class="unit-card-stat-potential">(+' + ch.pot.atk + ')</span>' : '') +
        '</span>' +
      '</div>' +
      '<div class="unit-card-stat">' +
        '<span class="unit-card-stat-label">DEF:</span>' +
        '<span class="unit-card-stat-value">' + ch.def +
        (bonus.def > 0 ? '<span class="unit-card-stat-bonus">+' + bonus.def + '</span>' : '') +
        (ch.pot && ch.pot.def ? '<span class="unit-card-stat-potential">(+' + ch.pot.def + ')</span>' : '') +
        '</span>' +
      '</div>' +
    '</div>';

    // 장비 슬롯 그리드
    html += '<div class="unit-card-equips">';
    ensureEquipSlots(ch);
    if (!ch.battle_potions) ch.battle_potions = [];
    if (!ch.siege_items) ch.siege_items = [];
    var invMap = {};
    for (var i = 0; i < inv.length; i++) {
      if (inv[i].type === 'equip') invMap[inv[i].eid] = inv[i];
    }
    for (var j = 0; j < EQUIP_SLOTS.length; j++) {
      var slot = EQUIP_SLOTS[j];
      var eid = ch.equip[slot];
      var equipped = eid ? invMap[eid] : null;
      var hasUpgrade = false;

      if (equipped) {
        // 더 좋은 장비가 인벤토리에 있는지 확인
        var betterExists = invEquips.some(function(it) {
          if (it.slot !== slot) return false;
          if (!canEquip(ch, it)) return false;
          return RARITY[it.rarity].tier > RARITY[equipped.rarity].tier;
        });
        hasUpgrade = betterExists;
      }

      var slotClass = 'unit-card-equip-slot';
      if (equipped) {
        slotClass += ' filled';
        if (hasUpgrade) slotClass += ' upgrade';
      }

      html += '<div class="' + slotClass + '"' +
              (equipped ? ' data-rarity="' + equipped.rarity + '"' : '') + '>' +
              (equipped ? '' : '-') +
              '</div>';
    }
    html += '</div>';

    // 스킬 정보 (있는 경우)
    if (skills.length > 0) {
      html += '<div class="unit-card-skills">';
      skills.forEach(function(sk) {
        var lv = getCharSkillLv(ch, sk.id);
        if (lv > 0) {
          html += '<span class="unit-card-skill">' + skillIcon(sk.id, 20) +
            '<span class="unit-card-skill-lv">' + lv + '</span></span>';
        }
      });
      html += '</div>';
    }

    card.innerHTML = html;
    card.className += (isInParty ? ' party-member' : '');
    card.onclick = (function(uid) {
      return function() {
        _selUid = uid;
        showEquipModal();
      };
    })(ch.uid);
    el.appendChild(card);
  });
}

// ── 장비 모달 표시/숨김 ──
function showEquipModal() {
  var overlay = document.getElementById('eq-modal-overlay');
  if (!overlay) {
    // 모달 생성
    overlay = document.createElement('div');
    overlay.id = 'eq-modal-overlay';
    overlay.className = 'eq-modal-overlay';

    var content = document.createElement('div');
    content.className = 'eq-modal-content';
    content.onclick = function(e) { e.stopPropagation(); };

    var header = document.createElement('div');
    header.className = 'eq-modal-header';
    header.innerHTML =
      '<h2>⚔️ ' + t('equip.detail_title') + '</h2>' +
      '<button class="eq-modal-close" onclick="hideEquipModal()">✕</button>';

    var body = document.createElement('div');
    body.className = 'eq-modal-body';
    body.innerHTML = '<div class="eq-body" id="eq-modal-body"></div>';

    content.appendChild(header);
    content.appendChild(body);
    overlay.appendChild(content);

    overlay.onclick = function() { hideEquipModal(); };

    document.body.appendChild(overlay);
  }

  // 모달 내용 렌더링
  renderModalBody();

  // 모달 표시
  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';
}

function hideEquipModal() {
  var overlay = document.getElementById('eq-modal-overlay');
  if (overlay) {
    overlay.classList.remove('active');
  }
  document.body.style.overflow = '';
}

// ── 모달 바디 렌더링 ──
function renderModalBody() {
  var body = document.getElementById('eq-modal-body');
  if (!body) return;
  if (!_selUid) {
    body.innerHTML = '<div class="eq-placeholder">' + t('equip.select_char') + '</div>';
    return;
  }
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === _selUid; });
  if (!ch) { body.innerHTML = ''; return; }
  ensureEquipSlots(ch);
  var inv = loadInventory();
  var invMap = {};
  for (var i = 0; i < inv.length; i++) { if (inv[i].type === 'equip') invMap[inv[i].eid] = inv[i]; }

  var html = '';

  // 2컬럼 레이아웃 래퍼
  html += '<div class="eq-body-layout">';

  // ──── 좌측 패널: 슬롯 + 스탯 + 세트 ────
  html += '<div class="eq-left">';

  // 슬롯 섹션
  html += '<div class="eq-section">';
  html += '<div class="eq-section-title">' + t('equip.slots_title') + '</div>';
  html += '<div class="eq-slots">';
  for (var s = 0; s < EQUIP_SLOTS.length; s++) {
    var slot = EQUIP_SLOTS[s];
    var eid = ch.equip[slot];
    var item = eid ? invMap[eid] : null;
    var locked = false;
    if (slot === 'offhand') {
      var wEid = ch.equip.weapon;
      var wItem = wEid ? invMap[wEid] : null;
      if (wItem && wItem.hand === '2h') locked = true;
    }
    html += '<div class="eq-slot' + (item ? ' filled' : '') + (locked ? ' locked' : '') + '" data-slot="' + slot + '">';
    html += '<div class="eq-slot-label">' + t('equip.slot.' + slot) + '</div>';
    if (locked) {
      html += '<div class="eq-slot-locked">&#128274;</div>';
    } else if (item) {
      html += '<div class="eq-slot-item" style="border-color:' + RARITY[item.rarity].color + '">';
      html += '<span class="eq-slot-rarity" style="color:' + RARITY[item.rarity].color + '">' + t('equip.rarity.' + item.rarity).charAt(0).toUpperCase() + '</span>';
      html += '<span class="eq-slot-name">' + t('equip.item.' + item.templateId) + '</span>';
      html += '</div>';
    } else {
      html += '<div class="eq-slot-empty">-</div>';
    }
    html += '</div>';
  }
  html += '</div>';
  html += '</div>'; // .eq-section

  // 스탯 섹션
  html += '<div class="eq-section">';
  html += '<div class="eq-section-title">' + t('equip.stats_title') + '</div>';
  var bonus = calcEquipBonus(ch);
  html += '<div class="eq-stats">';
  var statKeys = ['hp', 'atk', 'def', 'move', 'range'];
  for (var si = 0; si < statKeys.length; si++) {
    var sk = statKeys[si];
    var base = ch[sk] || 0;
    var bon = bonus[sk] || 0;
    html += '<div class="eq-stat">';
    html += '<span class="eq-stat-label">' + t('common.' + sk) + '</span>';
    html += '<span class="eq-stat-val">' + base + (bon > 0 ? '<span class="eq-stat-bonus">+' + bon + '</span>' : '') + '</span>';
    html += '</div>';
  }
  html += '</div>';
  html += '</div>'; // .eq-section

  // 세트 보너스 섹션 (조건부)
  var setCounts = {};
  for (var ss = 0; ss < EQUIP_SLOTS.length; ss++) {
    var sEid = ch.equip[EQUIP_SLOTS[ss]];
    if (!sEid) continue;
    var sItem = invMap[sEid];
    if (sItem && sItem.setId) setCounts[sItem.setId] = (setCounts[sItem.setId] || 0) + 1;
  }
  var hasSet = false;
  for (var sid in setCounts) { hasSet = true; break; }
  if (hasSet) {
    html += '<div class="eq-section">';
    html += '<div class="eq-set-info">';
    for (var setId in setCounts) {
      var cnt = setCounts[setId];
      var setDef = EQUIP_SETS[setId];
      html += '<div class="eq-set-row">';
      html += '<span class="eq-set-name">' + t('equip.set.' + setId) + '</span>';
      for (var th in setDef) {
        var active = cnt >= parseInt(th);
        var bonusStr = [];
        for (var bk in setDef[th]) bonusStr.push(t('common.' + bk) + '+' + setDef[th][bk]);
        html += '<span class="eq-set-bonus' + (active ? ' active' : '') + '">(' + th + ') ' + bonusStr.join(' ') + '</span>';
      }
      html += '</div>';
    }
    html += '</div>';
    html += '</div>'; // .eq-section
  }

  html += '</div>'; // .eq-left

  // ──── 우측 패널: 인벤토리 ────
  html += '<div class="eq-right">';
  html += '<div class="eq-section eq-section-fill">';
  html += '<div class="eq-section-title">' + t('equip.inventory') + '</div>';
  html += '<div class="eq-inv-tabs">';
  var filters = [
    { key: 'all', label: t('party.filter_all') },
    { key: 'weapon', label: t('equip.slot.weapon') },
    { key: 'armor', label: t('equip.filter_armor') },
    { key: 'accessory', label: t('equip.filter_accessory') }
  ];
  for (var fi = 0; fi < filters.length; fi++) {
    html += '<button class="eq-inv-tab' + (_invFilter === filters[fi].key ? ' active' : '') + '" data-filter="' + filters[fi].key + '">' + filters[fi].label + '</button>';
  }
  html += '</div>';
  html += '<div class="eq-inv-list" id="eq-inv-list"></div>';
  html += '</div>'; // .eq-section
  html += '</div>'; // .eq-right

  html += '</div>'; // .eq-body-layout

  body.innerHTML = html;

  // ── Bind slot click (unequip) ──
  body.querySelectorAll('.eq-slot.filled').forEach(function(el) {
    el.onclick = function() {
      var sl = el.dataset.slot;
      unequipItem(_selUid, sl);
    };
  });

  // ── Bind filter tabs ──
  body.querySelectorAll('.eq-inv-tab').forEach(function(btn) {
    btn.onclick = function() {
      _invFilter = btn.dataset.filter;
      renderModalBody();
    };
  });

  // ── Render inventory list ──
  renderInventoryInModal(ch);
}

// ── 모달 내 인벤토리 렌더링 ──
function renderInventoryInModal(ch) {
  var list = document.getElementById('eq-inv-list');
  if (!list) return;
  list.innerHTML = '';
  var inv = loadInventory();
  var equips = inv.filter(function(it) { return it.type === 'equip'; });

  // Filter
  if (_invFilter === 'weapon') {
    equips = equips.filter(function(it) { return it.slot === 'weapon' || it.slot === 'offhand'; });
  } else if (_invFilter === 'armor') {
    equips = equips.filter(function(it) { return it.slot === 'helmet' || it.slot === 'armor' || it.slot === 'boots'; });
  } else if (_invFilter === 'accessory') {
    equips = equips.filter(function(it) { return it.slot === 'necklace' || it.slot === 'earring' || it.slot === 'ring'; });
  }

  // Sort: rarity desc, then slot
  equips.sort(function(a, b) {
    var ra = RARITY[a.rarity].tier, rb = RARITY[b.rarity].tier;
    if (rb !== ra) return rb - ra;
    return EQUIP_SLOTS.indexOf(a.slot) - EQUIP_SLOTS.indexOf(b.slot);
  });

  if (!equips.length) {
    list.innerHTML = '<div class="eq-inv-empty">' + t('equip.no_items') + '</div>';
    return;
  }

  equips.forEach(function(item) {
    var rc = RARITY[item.rarity].color;
    var canEquipThis = canEquip(ch, item);
    var isEquipped = !!item.equipped;
    var isEquippedHere = false;
    for (var s = 0; s < EQUIP_SLOTS.length; s++) {
      if (ch.equip[EQUIP_SLOTS[s]] === item.eid) { isEquippedHere = true; break; }
    }
    var isEquippedOther = isEquipped && !isEquippedHere;
    var statsArr = [];
    for (var st in item.stats) statsArr.push(t('common.' + st) + '+' + item.stats[st]);

    // 강화 레벨 표시
    var enhanceLvHtml = '';
    if (item.enhanceLv > 0) {
      enhanceLvHtml = '<span class="eq-inv-enhance-lv">+' + item.enhanceLv + '</span>';
    }

    // 사용가능 직업 아이콘들 (좌측 상단, 제한된 경우만 표시)
    var clsIconHtml = '';
    var totalClasses = Object.keys(CLASS_GROUP_MAP).length; // 전체 직업 개수
    if (item.clsRestrict && item.clsRestrict.length > 0 && item.clsRestrict.length < totalClasses) {
      clsIconHtml = '<div class="eq-inv-cls-icons">';
      for (var c = 0; c < item.clsRestrict.length; c++) {
        clsIconHtml += '<div class="eq-inv-cls-icon">' + clsIcon(item.clsRestrict[c], 20) + '</div>';
      }
      clsIconHtml += '</div>';
    }

    // TODO: 나중에 image/icon/64x64/*.png 아이콘으로 변경
    var itemEmoji = getEquipEmoji(item.templateId);
    var card = document.createElement('div');
    card.className = 'eq-inv-card' + (isEquippedHere ? ' equipped-here' : isEquippedOther ? ' equipped-other' : '');

    // 새로운 카드 HTML 구조
    card.innerHTML =
      '<div class="eq-inv-header">' +
        clsIconHtml +
        '<span class="eq-inv-rarity" style="color:' + rc + ';border-color:' + rc + '">' +
          t('equip.rarity.' + item.rarity).charAt(0).toUpperCase() +
        '</span>' +
      '</div>' +
      '<div class="eq-inv-info">' +
        '<span class="eq-inv-emoji">' + itemEmoji + '</span>' +
        '<span class="eq-inv-name">' +
          t('equip.item.' + item.templateId) +
          enhanceLvHtml +
        '</span>' +
        (statsArr.length ? '<span class="eq-inv-stats">' + statsArr.join(' ') + '</span>' : '') +
        (item.setId ? '<span class="eq-inv-set">' + t('equip.set.' + item.setId) + '</span>' : '') +
      '</div>' +
      '<div class="eq-inv-actions">' +
        (isEquippedHere ?
          '<button class="eq-inv-btn eq-unequip-btn">' + t('equip.unequip_btn') + '</button>'
        :
          (canEquipThis && !isEquippedOther ?
            '<button class="eq-inv-btn eq-equip-btn">' + t('equip.equip_btn') + '</button>' +
            '<button class="eq-inv-btn eq-sell-btn">' +
              t('equip.sell_btn', { gold: SELL_PRICE[item.rarity] }) + '</button>'
          :
            (!isEquipped ?
              '<button class="eq-inv-btn eq-sell-btn">' +
                t('equip.sell_btn', { gold: SELL_PRICE[item.rarity] }) + '</button>'
            : '')
          )
        ) +
      '</div>';

    // 이벤트 리스너
    var equipBtn = card.querySelector('.eq-equip-btn');
    if (equipBtn) {
      equipBtn.onclick = function() { equipItemInModal(_selUid, item.eid); };
    }

    var sellBtn = card.querySelector('.eq-sell-btn');
    if (sellBtn) {
      sellBtn.onclick = function() { sellEquipInModal(item.eid); };
    }

    var unequipBtn = card.querySelector('.eq-unequip-btn');
    if (unequipBtn) {
      unequipBtn.onclick = function() { unequipItemInModal(_selUid, item.slot); };
    }

    list.appendChild(card);
  });
}

// ── 모달 내 장비 장착/판매 (갱신 포함) ──
function equipItemInModal(uid, eid) {
  equipItem(uid, eid);
  renderChars(); // 카드 리스트 갱신
  renderModalBody(); // 모달 내용 갱신
}

function sellEquipInModal(eid) {
  sellEquip(eid);
  renderChars(); // 카드 리스트 갱신
  renderModalBody(); // 모달 내용 갱신
}

// ── 모달 내 장비 장착해제 (갱신 포함) ──
function unequipItemInModal(uid, slot) {
  unequipItem(uid, slot);
  renderChars(); // 카드 리스트 갱신
  renderModalBody(); // 모달 내용 갱신
}

// ── Core equip functions ──
function canEquip(ch, item) {
  if (!ch || !item) return false;
  if (item.clsRestrict && item.clsRestrict.indexOf(ch.cls) === -1) return false;
  if (item.slot === 'offhand') {
    ensureEquipSlots(ch);
    var inv = loadInventory();
    var wEid = ch.equip.weapon;
    if (wEid) {
      var wItem = inv.find(function(x) { return x.eid === wEid; });
      if (wItem && wItem.hand === '2h') return false;
    }
  }
  return true;
}

function equipItem(uid, eid) {
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch) return;
  ensureEquipSlots(ch);
  var inv = loadInventory();
  var item = inv.find(function(x) { return x.eid === eid; });
  if (!item) return;

  // Unequip from other character if needed
  if (item.equipped !== null && item.equipped !== uid) {
    var other = roster.chars.find(function(c) { return c.uid === item.equipped; });
    if (other) {
      ensureEquipSlots(other);
      for (var s = 0; s < EQUIP_SLOTS.length; s++) {
        if (other.equip[EQUIP_SLOTS[s]] === eid) { other.equip[EQUIP_SLOTS[s]] = null; break; }
      }
    }
  }

  // Unequip current item in slot
  var oldEid = ch.equip[item.slot];
  if (oldEid) {
    var oldItem = inv.find(function(x) { return x.eid === oldEid; });
    if (oldItem) oldItem.equipped = null;
  }

  // 2h weapon: also unequip offhand
  if (item.slot === 'weapon' && item.hand === '2h') {
    var ohEid = ch.equip.offhand;
    if (ohEid) {
      var ohItem = inv.find(function(x) { return x.eid === ohEid; });
      if (ohItem) ohItem.equipped = null;
    }
    ch.equip.offhand = null;
  }

  ch.equip[item.slot] = eid;
  item.equipped = uid;
  saveRoster(roster);
  saveInventory(inv);
  eqRenderAll();
}

function unequipItem(uid, slot) {
  var roster = getRoster();
  var ch = roster.chars.find(function(c) { return c.uid === uid; });
  if (!ch) return;
  ensureEquipSlots(ch);
  var eid = ch.equip[slot];
  if (!eid) return;
  var inv = loadInventory();
  var item = inv.find(function(x) { return x.eid === eid; });
  if (item) item.equipped = null;
  ch.equip[slot] = null;
  saveRoster(roster);
  saveInventory(inv);
  eqRenderAll();
}

function sellEquip(eid) {
  var inv = loadInventory();
  var item = inv.find(function(x) { return x.eid === eid; });
  if (!item || !!item.equipped) return;
  var price = SELL_PRICE[item.rarity] || 30;
  showConfirm(
    t('equip.sell_confirm', { name: t('equip.item.' + item.templateId), gold: price }),
    function() {
      var inv2 = loadInventory();
      inv2 = inv2.filter(function(x) { return x.eid !== eid; });
      saveInventory(inv2);
      _gold += price;
      saveGold(_gold);
      updatePageGold();
      eqRenderAll();
    }
  );
}

function eqRenderAll() {
  renderEquipFilterTabs();
  renderChars();
}

// ══════════════════════════════════════════════
// ── 아이템 탭 (물약 인벤토리) ─────────────────
// ══════════════════════════════════════════════

var POTION_INFO = {
  'exp_s': { nameKey: 'shop.potion_small', icon: '\ud83e\uddea' },
  'exp_m': { nameKey: 'shop.potion_medium', icon: '\u2697\ufe0f' },
  'exp_l': { nameKey: 'shop.potion_large', icon: '\ud83c\udfd0' }
};

function renderItemTab() {
  var list = document.getElementById('item-list');
  if (!list) return;
  list.innerHTML = '';

  var inv = loadInventory();
  var potions = inv.filter(function(it) { return it.type === 'potion'; });
  var sieges = inv.filter(function(it) { return it.type === 'siege'; });

  if (!potions.length && !sieges.length) {
    list.innerHTML = '<div class="item-empty">' + t('party.no_items') + '</div>';
    return;
  }

  // 물약 섹션
  if (potions.length > 0) {
    var potionSection = document.createElement('div');
    potionSection.className = 'item-section';
    potionSection.innerHTML = '<div class="item-section-title">💊 경험치 물약</div>';

    // 물약 종류별 그룹핑
    var groups = {};
    potions.forEach(function(p) {
      var id = p.potionId;
      if (!groups[id]) groups[id] = { potionId: id, exp: p.exp, icon: p.icon, count: 0 };
      groups[id].count++;
    });

    var order = ['exp_s', 'exp_m', 'exp_l'];
    order.forEach(function(pid) {
      var g = groups[pid];
      if (!g) return;
      var info = POTION_INFO[pid];
      var potionName = info ? t(info.nameKey) : pid;

      var card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML =
        '<div class="item-icon">' + g.icon + '</div>' +
        '<div class="item-info">' +
          '<div class="item-name">' + potionName + '</div>' +
          '<div class="item-exp">EXP +' + g.exp + '</div>' +
        '</div>' +
        '<div class="item-count">' + t('party.potion_count', { count: g.count }) + '</div>' +
        '<button class="item-use-btn">' + t('party.potion_use') + '</button>';
      card.querySelector('.item-use-btn').onclick = function() {
        showPotionUseModal(pid);
      };
      potionSection.appendChild(card);
    });

    list.appendChild(potionSection);
  }

  // 공성 아이템 섹션
  if (sieges.length > 0) {
    var siegeSection = document.createElement('div');
    siegeSection.className = 'item-section';
    siegeSection.innerHTML = '<div class="item-section-title">⚙️ 공성 아이템</div>';

    // 공성 아이템 종류별 그룹핑
    var siegeGroups = {};
    sieges.forEach(function(s) {
      var id = s.siegeId;
      if (!siegeGroups[id]) {
        var siegeInfo = SIEGE_ITEMS.find(function(x) { return x.id === id; });
        siegeGroups[id] = { siegeId: id, icon: siegeInfo ? siegeInfo.icon : '⚙️', count: 0 };
      }
      siegeGroups[id].count++;
    });

    Object.keys(siegeGroups).forEach(function(sid) {
      var sg = siegeGroups[sid];
      var card = document.createElement('div');
      card.className = 'item-card';
      card.innerHTML =
        '<div class="item-icon">' + sg.icon + '</div>' +
        '<div class="item-info">' +
          '<div class="item-name">' + t('shop.' + sg.siegeId) + '</div>' +
        '</div>' +
        '<div class="item-count">' + t('party.potion_count', { count: sg.count }) + '</div>';
      siegeSection.appendChild(card);
    });

    list.appendChild(siegeSection);
  }
}

function showPotionUseModal(potionId) {
  var inv = loadInventory();
  var potion = inv.find(function(it) { return it.type === 'potion' && it.potionId === potionId; });
  if (!potion) return;

  var roster = getRoster();
  var alive = roster.chars.filter(function(c) { return !c.dead && !c.cls.startsWith('summon_') && c.lv < MAX_LEVEL; });

  if (!alive.length) {
    showAlert(t('party.no_available_chars'));
    return;
  }

  var info = POTION_INFO[potionId];
  var potionName = info ? t(info.nameKey) : potionId;

  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = t('party.potion_use') + ' - ' + potionName;
  document.getElementById('modal-title').className = '';
  var h = '<div class="potion-target-list">';
  var names = t('character.names');
  alive.forEach(function(ch) {
    var d = JAB[ch.cls];
    var charName = ch.customName || names[ch.nameId] || d.icon;
    var expNeed = expForLevel(ch.lv);
    h += '<div class="pt-btn" data-uid="' + ch.uid + '">' +
      '<span class="pt-icon">' + clsIcon(ch.cls, 20) + '</span>' +
      '<span class="pt-info">' + charName + ' Lv.' + ch.lv + '</span>' +
      '<span class="pt-exp">' + (ch.exp || 0) + '/' + expNeed + '</span>' +
      '</div>';
  });
  h += '</div>';
  document.getElementById('modal-sub').innerHTML = potion.icon + ' ' + potionName + ' (EXP +' + potion.exp + ')<br><br>' + h;
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var cb = document.createElement('button');
  cb.className = 'modal-btn secondary';
  cb.textContent = t('common.cancel');
  cb.onclick = function() { ov.classList.remove('show'); };
  bt.appendChild(cb);
  ov.classList.add('show');
  document.querySelectorAll('.pt-btn').forEach(function(b) {
    b.onclick = function() {
      var uid = +b.dataset.uid;
      // 인벤토리에서 물약 1개 제거
      var inv2 = loadInventory();
      var idx = -1;
      for (var i = 0; i < inv2.length; i++) {
        if (inv2[i].type === 'potion' && inv2[i].potionId === potionId) { idx = i; break; }
      }
      if (idx === -1) { ov.classList.remove('show'); return; }
      var usedPotion = inv2[idx];
      inv2.splice(idx, 1);
      saveInventory(inv2);

      // EXP 적용
      var r = gainExp(uid, usedPotion.exp);
      ov.classList.remove('show');
      renderItemTab();

      var ch = getChar(uid);
      var d = JAB[ch.cls];
      var charName = ch.customName || names[ch.nameId] || d.icon;
      if (r.leveled > 0) {
        setTimeout(function() {
          showAlert(charName + '\nLv.' + r.prevLv + ' \u2192 Lv.' + ch.lv +
            (r.leveled > 1 ? ' (' + r.leveled + t('party.potion_levelup_multi') + ')' : ''));
        }, 100);
      } else {
        showAlert(charName + ' ' + t('party.potion_use_success', { exp: usedPotion.exp }));
      }
    };
  });
}


// ═══════════════════════════════════════════
// 전투 포션 & 공성 아이템 관리
// ═══════════════════════════════════════════

// ── 전투 포션 리스트 렌더링 (전체 아군 공유) ──
function renderBattlePotionsList() {
  var list = document.getElementById('eq-potions-list');
  if (!list) return;
  list.innerHTML = '';

  var inv = loadInventory();
  var availablePotions = inv.filter(function(item) { return item.type === 'battle_potion'; });

  if (availablePotions.length === 0) {
    list.innerHTML = '<div style="font-size:12px;color:#9ca3af;">인벤토리에 포션이 없습니다</div>';
    return;
  }

  // 포션 버튼들 (인벤토리에 있는 것만) - 무제한 선택
  availablePotions.forEach(function(item) {
    var pot = BATTLE_POTIONS[item.potionId];
    if (!pot) return;

    var isSelected = _globalBattlePotions.indexOf(item.pid) !== -1;

    var btn = document.createElement('button');
    btn.className = 'eq-potion-btn' + (isSelected ? ' selected' : '');
    btn.style.cssText = 'flex:0 0 auto;padding:6px 10px;border:1px solid #ddd;border-radius:4px;' +
      'background:' + (isSelected ? '#4ade80' : '#f3f4f6') + ';' +
      'cursor:pointer;';
    var qty = item.quantity || 1;
    btn.innerHTML = pot.icon + ' ' + t('battle_potions.' + item.potionId) + ' ×' + qty;
    btn.title = t('battle_potions.' + item.potionId) + ' | ×' + qty;

    btn.onclick = (function(potionPid, selected) {
      return function() {
        toggleBattlePotion(potionPid, selected);
      };
    })(item.pid, isSelected);

    list.appendChild(btn);
  });
}

// ── 포션 토글 (전체 아군 공유, 무제한) ──
function toggleBattlePotion(potionPid, isSelected) {
  if (isSelected) {
    // 제거
    var idx = _globalBattlePotions.indexOf(potionPid);
    if (idx !== -1) _globalBattlePotions.splice(idx, 1);
  } else {
    // 무제한 추가
    _globalBattlePotions.push(potionPid);
  }

  saveGlobalBattleItems();
  renderChars();
  renderModalBody();
}

// ── 공성 아이템 리스트 렌더링 (아이콘 + 수량만 표시) ──
function renderSiegeItemsList() {
  var list = document.getElementById('eq-sieges-list');
  if (!list) return;
  list.innerHTML = '';

  var inv = loadInventory();
  var availableSieges = inv.filter(function(item) { return item.type === 'siege'; });

  if (availableSieges.length === 0) {
    list.innerHTML = '<div style="font-size:12px;color:#9ca3af;">인벤토리에 공성 아이템이 없습니다</div>';
    return;
  }

  // 공성 아이템 (아이콘 + 수량만 표시)
  availableSieges.forEach(function(item) {
    var siege = SIEGE_ITEMS.find(function(s) { return s.id === item.siegeId; });
    if (!siege) return;

    var div = document.createElement('div');
    div.style.cssText = 'display:inline-flex;align-items:center;gap:4px;padding:6px 10px;' +
      'background:#f3f4f6;border-radius:4px;margin-right:8px;margin-bottom:6px;font-size:12px;';
    var qty = item.quantity || 1;
    div.innerHTML = siege.icon + ' <span style="font-weight:600;">×' + qty + '</span>';
    div.title = t('shop.' + item.siegeId) + ' | ×' + qty;

    list.appendChild(div);
  });
}

// ── 초기화 ───────────────────────────────
var init = async function() {
  await i18nInit();
  var nav = loadNav();
  _cStage = (nav && nav.cStage) ? nav.cStage : null;
  _practiceMode = (nav && nav.practiceMode) ? nav.practiceMode : false;

  // 다중 파티 로드 (레거시 마이그레이션 포함)
  _parties = loadParties();
  _currentPartyId = _parties.activePartyId;

  loadGlobalBattleItems();

  // 죽은 유닛 제거 (모든 파티에서)
  var roster = getRoster();
  _parties.parties.forEach(function(party) {
    party.slots = party.slots.filter(function(uid) {
      if (!uid) return true;
      var ch = roster.chars.find(function(c) { return c.uid === uid; });
      return ch && !ch.dead;
    });
  });
  saveParties(_parties);

  // Migrate: 인벤토리 장비 아이템의 equipped 필드 정규화
  try {
    var inv = loadInventory(), invChanged = false;
    for (var mi = 0; mi < inv.length; mi++) {
      if (inv[mi].type === 'equip' && inv[mi].equipped === undefined) {
        inv[mi].equipped = null; invChanged = true;
      }
    }
    if (invChanged) saveInventory(inv);
  } catch(_) {}

  // 페이지 탭 바인딩
  document.querySelectorAll('.game-tabs .game-tab').forEach(function(btn) {
    btn.onclick = function() { switchPageTab(btn.getAttribute('data-ptab')); };
  });

  // localStorage에서 저장된 탭 상태 복원
  var savedTab = localStorage.getItem('ps_active_tab') || 'party';
  switchPageTab(savedTab);

  // 모달 닫기 버튼 바인딩
  var unitModalClose = document.getElementById('unit-modal-close');
  if (unitModalClose) {
    unitModalClose.onclick = closeUnitModal;
  }

  // 모달 오버레이 클릭으로 닫기
  var unitModalOverlay = document.getElementById('unit-select-modal-overlay');
  if (unitModalOverlay) {
    unitModalOverlay.onclick = function(e) {
      if (e.target === unitModalOverlay) closeUnitModal();
    };
  }

  // ESC 키로 모달 닫기
  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && unitModalOverlay && unitModalOverlay.style.display === 'flex') {
      closeUnitModal();
    }
  });

  updatePageGold();

  // 다중 파티 UI 렌더링
  renderPartyTabs();
  renderPartySlots();

  // 출격 버튼 표시 여부 업데이트
  updateStartButtonVisibility();

  renderBottomNav();
  setTimeout(function() { document.getElementById('splash').style.display = 'none'; }, 300);
};

// ═══════════════════════════════════════════
// 강화 시스템 (Enhancement System)
// ═══════════════════════════════════════════

// 강화 목록 렌더링
function renderEnhanceList() {
  var inv = loadInventory();
  var enhanceable = inv.filter(function(x) {
    return x.type === 'equip' && !x.equipped && canEnhance(x);
  });

  var html = '';
  for (var i = 0; i < enhanceable.length; i++) {
    var item = enhanceable[i];
    var enhancedStats = getEnhancedStats(item);
    var currentStats = item.stats;
    var rate = calcEnhanceRate(item);
    var ratePercent = Math.round(rate * 100);
    var costGold = calcEnhanceCost(item);

    var rateClass = rate >= 0.80 ? 'rate-high' : rate >= 0.40 ? 'rate-mid' : 'rate-low';

    // 성공 시 예상 스탯 (다음 레벨)
    var nextLvl = item.enhanceLv + 1;
    var nextMult = 1 + getEnhanceMultiplier(nextLvl);
    var nextStats = {};
    for (var stat in currentStats) {
      nextStats[stat] = Math.round(currentStats[stat] * nextMult);
    }

    var gainText = '';
    if (currentStats.atk) gainText += ' ATK+' + (nextStats.atk - currentStats.atk);
    if (currentStats.def) gainText += ' DEF+' + (nextStats.def - currentStats.def);
    if (currentStats.hp) gainText += ' HP+' + (nextStats.hp - currentStats.hp);

    // TODO: 나중에 image/icon/64x64/*.png 아이콘으로 변경
    var itemEmoji = getEquipEmoji(item.templateId);
    html += '<div class="enhance-card" onclick="showEnhanceModal(\'' + item.eid + '\')">' +
      '<div class="enhance-icon">' + itemEmoji + '</div>' +
      '<div class="enhance-info">' +
        '<div class="enhance-header">' +
          '<div class="enhance-name" title="' + t('equip.item.' + item.templateId) + '">' + t('equip.item.' + item.templateId) + '</div>' +
          '<div class="enhance-level">' +
            (item.enhanceLv > 0 ? '+' + item.enhanceLv : 'Lv.0') + ' → +' + nextLvl +
          '</div>' +
        '</div>' +
        '<div class="enhance-details">' +
          '<div class="enhance-stats-current">' + gainText + '</div>' +
          '<div class="enhance-rate-cost">' + ratePercent + '% • ' + costGold + 'G</div>' +
        '</div>' +
      '</div>' +
      '<button class="enhance-btn" onclick="event.stopPropagation(); showEnhanceModal(\'' + item.eid + '\');">' + t('enhance.button_enhance') + '</button>' +
    '</div>';
  }

  if (enhanceable.length === 0) {
    html = '<div style="text-align:center;padding:40px 20px;color:var(--dim);font-size:12px;">' +
           t('enhance.no_items') + '</div>';
  }

  document.getElementById('enhance-list').innerHTML = html;
}

// 강화 모달 표시 (단계 2: 재료 선택)
function showEnhanceModal(targetEid) {
  var inv = loadInventory();
  var target = inv.find(function(x) { return x.eid === targetEid; });
  if (!target) return;

  var materials = inv.filter(function(x) {
    return x.type === 'equip' && x.slot === target.slot && x.eid !== targetEid && !x.equipped;
  });

  if (materials.length === 0) {
    showAlert(t('enhance.no_materials'));
    return;
  }

  var overlay = document.getElementById('enhance-modal-overlay');
  if (!overlay) {
    overlay = document.createElement('div');
    overlay.id = 'enhance-modal-overlay';
    overlay.className = 'enhance-modal-overlay';
    overlay.onclick = function(e) { if (e.target === overlay) hideEnhanceModal(); };
    document.body.appendChild(overlay);
  }

  var html = '<div class="enhance-modal" onclick="event.stopPropagation();">' +
    '<div class="enhance-modal-header">' +
      '<div class="enhance-modal-title" data-i18n="enhance.select_material">' + t('enhance.select_material') + '</div>' +
      '<div class="enhance-modal-close" onclick="hideEnhanceModal();">✕</div>' +
    '</div>' +
    '<div class="enhance-modal-body">' +
      '<div style="font-size:11px;color:var(--dim);">' + t('enhance.material_hint') + '</div>' +
      '<div class="enhance-material-list">';

  for (var i = 0; i < materials.length; i++) {
    var mat = materials[i];
    // TODO: 나중에 image/icon/64x64/*.png 아이콘으로 변경
    var matEmoji = getEquipEmoji(mat.templateId);
    html += '<div class="enhance-material-item" onclick="showEnhanceConfirmModal(\'' + targetEid + '\', \'' + mat.eid + '\')">' +
      '<div class="enhance-material-icon">' + matEmoji + '</div>' +
      '<div class="enhance-material-info">' +
        '<div class="enhance-material-name">' + t('equip.item.' + mat.templateId) + '</div>' +
        '<div class="enhance-material-rarity">' + t('equip.rarity.' + mat.rarity) + (mat.enhanceLv > 0 ? ' +' + mat.enhanceLv : '') + '</div>' +
      '</div>' +
    '</div>';
  }

  html += '</div></div></div>';
  overlay.innerHTML = html;
  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';
}

// 강화 최종 확인 모달 (단계 3)
function showEnhanceConfirmModal(targetEid, materialEid) {
  var inv = loadInventory();
  var target = inv.find(function(x) { return x.eid === targetEid; });
  var material = inv.find(function(x) { return x.eid === materialEid; });
  if (!target || !material) return;

  var cost = calcEnhanceCost(target);
  var rate = calcEnhanceRate(target);
  var ratePercent = Math.round(rate * 100);

  // 현재 스탯과 성공 시 예상 스탯
  var currentStats = getEnhancedStats(target);
  var nextLvl = target.enhanceLv + 1;
  var nextMult = 1 + getEnhanceMultiplier(nextLvl);
  var nextStats = {};
  for (var stat in target.stats) {
    nextStats[stat] = Math.round(target.stats[stat] * nextMult);
  }

  var overlay = document.getElementById('enhance-modal-overlay');
  if (!overlay) {
    overlay = document.createElement('div');
    overlay.id = 'enhance-modal-overlay';
    overlay.className = 'enhance-modal-overlay';
    overlay.onclick = function(e) { if (e.target === overlay) hideEnhanceModal(); };
    document.body.appendChild(overlay);
  }

  var pityHtml = '';
  if (target.enhanceAttempts > 0) {
    pityHtml = '<div class="enhance-pity-counter">⚠️ ' +
      t('enhance.pity_counter', { current: target.enhanceAttempts, total: ENHANCE_PITY_THRESHOLD }) +
      '</div>';
  }

  var rateColor = rate >= 0.80 ? '#4ade80' : rate >= 0.40 ? '#fbbf24' : '#ef4444';

  // 성공 시 스탯 증가량
  var gainHtml = '';
  for (var stat in nextStats) {
    if (currentStats[stat]) {
      var gain = nextStats[stat] - currentStats[stat];
      if (gain > 0) {
        gainHtml += (gainHtml ? ' ' : '') + stat.toUpperCase() + '+' + gain;
      }
    }
  }

  var html = '<div class="enhance-modal enhance-confirm-modal" onclick="event.stopPropagation();">' +
    '<div class="enhance-modal-header">' +
      '<div class="enhance-modal-title" data-i18n="enhance.confirm_title">' + t('enhance.confirm_title') + '</div>' +
      '<div class="enhance-modal-close" onclick="hideEnhanceModal();">✕</div>' +
    '</div>' +
    '<div class="enhance-modal-body enhance-confirm-content">' +
      '<div class="enhance-confirm-section">' +
        '<div class="enhance-confirm-label">📊 ' + t('enhance.target_item') + '</div>' +
        '<div class="enhance-confirm-value">' + t('equip.item.' + target.templateId) + (target.enhanceLv > 0 ? ' +' + target.enhanceLv : '') + '</div>' +
      '</div>' +
      '<div class="enhance-confirm-section" style="background:rgba(74,222,128,.1);border:1px solid rgba(74,222,128,.3);">' +
        '<div class="enhance-confirm-label" style="color:#4ade80;">✨ 성공 시 보상 (+' + nextLvl + ')</div>' +
        '<div class="enhance-confirm-value" style="color:#4ade80;font-size:14px;font-weight:700;">' + gainHtml + '</div>' +
        '<div style="font-size:10px;color:#4ade80;margin-top:4px;">확률: <span style="font-size:12px;font-weight:700;">' + ratePercent + '%</span></div>' +
        pityHtml +
      '</div>' +
      '<div class="enhance-confirm-section">' +
        '<div class="enhance-confirm-label">⚙️ ' + t('enhance.material_item') + '</div>' +
        '<div class="enhance-confirm-value">' + t('equip.item.' + material.templateId) + (material.enhanceLv > 0 ? ' +' + material.enhanceLv : '') + '</div>' +
        '<div style="font-size:9px;color:#ef4444;margin-top:4px;">⚠️ ' + t('enhance.material_consumed') + '</div>' +
      '</div>' +
      '<div class="enhance-confirm-section">' +
        '<div class="enhance-confirm-label">💰 ' + t('common.gold') + '</div>' +
        '<div class="enhance-confirm-value">' + cost + ' G</div>' +
      '</div>' +
    '</div>' +
    '<div class="enhance-modal-buttons">' +
      '<button class="enhance-modal-btn" onclick="hideEnhanceModal();">' + t('common.cancel') + '</button>' +
      '<button class="enhance-modal-btn primary" onclick="executeEnhance(\'' + targetEid + '\', \'' + materialEid + '\');">' +
        t('enhance.button_enhance') + '</button>' +
    '</div>' +
  '</div>';

  overlay.innerHTML = html;
  overlay.classList.add('active');
  document.body.style.overflow = 'hidden';
}

// 모달 닫기
function hideEnhanceModal() {
  var overlay = document.getElementById('enhance-modal-overlay');
  if (overlay) overlay.classList.remove('active');
  document.body.style.overflow = '';
}

// 강화 실행
function executeEnhance(targetEid, materialEid) {
  var inv = loadInventory();
  var target = inv.find(function(x) { return x.eid === targetEid; });
  var material = inv.find(function(x) { return x.eid === materialEid; });

  // 유효성 검사
  if (!target || !material) {
    showAlert(t('enhance.error_invalid'));
    return;
  }
  if (target.equipped) {
    showAlert(t('enhance.error_equipped'));
    return;
  }
  if (material.equipped) {
    showAlert(t('enhance.error_material_equipped'));
    return;
  }
  if (target.slot !== material.slot) {
    showAlert(t('enhance.error_slot_mismatch'));
    return;
  }

  var cost = calcEnhanceCost(target);
  var gold = loadGold();
  if (gold < cost) {
    showAlert(t('messages.not_enough_gold'));
    return;
  }

  // 재료 소비
  inv = inv.filter(function(x) { return x.eid !== materialEid; });

  // 강화 시도
  var rate = calcEnhanceRate(target);
  var roll = Math.random();
  var succeeded = roll < rate;

  if (succeeded) {
    // 성공
    target.enhanceLv = (target.enhanceLv || 0) + 1;
    target.enhanceAttempts = 0; // Pity 초기화
    saveGold(gold - cost);
    saveInventory(inv);

    var newStats = getEnhancedStats(target);
    var statStr = '';
    if (newStats.hp) statStr += ' HP+' + newStats.hp;
    if (newStats.atk) statStr += ' ATK+' + newStats.atk;
    if (newStats.def) statStr += ' DEF+' + newStats.def;

    hideEnhanceModal();
    showAlert(
      t('enhance.success_title') + '\n\n' +
      '✨ ' + t('equip.item.' + target.templateId) + ' → +' + target.enhanceLv + '\n' +
      statStr
    );
  } else {
    // 실패
    target.enhanceAttempts = (target.enhanceAttempts || 0) + 1;
    saveGold(gold - cost);
    saveInventory(inv);

    var attempts = target.enhanceAttempts;
    var pityMsg = '';
    if (attempts >= ENHANCE_PITY_THRESHOLD) {
      pityMsg = '\n\n✅ ' + t('enhance.pity_ready');
    } else {
      pityMsg = '\n📊 ' + t('enhance.fail_pity', { count: attempts });
    }

    hideEnhanceModal();
    showAlert(t('enhance.fail_title') + '\n' + t('enhance.fail_msg') + pityMsg);
  }

  _gold = loadGold();
  renderEnhanceList();
  updatePageGold();
}

