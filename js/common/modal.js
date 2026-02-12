// 공통 모달 유틸리티
// modal-overlay > modal-box > modal-title, modal-sub, modal-buttons 구조 필요

function showAlert(msg, onOk) {
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = '';
  document.getElementById('modal-title').className = '';
  document.getElementById('modal-sub').innerHTML = msg.replace(/\n/g, '<br>');
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var ok = document.createElement('button');
  ok.className = 'modal-btn';
  ok.textContent = window.t ? t('common.confirm') : 'OK';
  ok.onclick = function() { ov.classList.remove('show'); if (onOk) onOk(); };
  bt.appendChild(ok);
  ov.classList.add('show');
}

function showConfirm(msg, onYes, onNo) {
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = window.t ? t('common.confirm') : 'Confirm';
  document.getElementById('modal-title').className = '';
  document.getElementById('modal-sub').innerHTML = msg.replace(/\n/g, '<br>');
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var y = document.createElement('button');
  y.className = 'modal-btn';
  y.textContent = window.t ? t('common.confirm') : 'OK';
  y.onclick = function() { ov.classList.remove('show'); if (onYes) onYes(); };
  bt.appendChild(y);
  var n = document.createElement('button');
  n.className = 'modal-btn secondary';
  n.textContent = window.t ? t('common.cancel') : 'Cancel';
  n.onclick = function() { ov.classList.remove('show'); if (onNo) onNo(); };
  bt.appendChild(n);
  ov.classList.add('show');
}

function showPrompt(msg, defaultVal, onOk, onCancel) {
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = '';
  document.getElementById('modal-title').className = '';
  document.getElementById('modal-sub').innerHTML = msg.replace(/\n/g, '<br>') +
    '<br><input id="modal-prompt-input" type="text" maxlength="10" value="' + (defaultVal || '').replace(/"/g, '&quot;') + '" style="width:90%;padding:8px;margin-top:8px;border:1px solid #f0c040;border-radius:6px;background:var(--card);color:#fff;font-size:14px;text-align:center;outline:none">';
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  var y = document.createElement('button');
  y.className = 'modal-btn';
  y.textContent = window.t ? t('common.confirm') : 'OK';
  y.onclick = function() {
    var val = document.getElementById('modal-prompt-input').value.trim();
    ov.classList.remove('show');
    if (onOk) onOk(val);
  };
  bt.appendChild(y);
  var n = document.createElement('button');
  n.className = 'modal-btn secondary';
  n.textContent = window.t ? t('common.cancel') : 'Cancel';
  n.onclick = function() { ov.classList.remove('show'); if (onCancel) onCancel(); };
  bt.appendChild(n);
  ov.classList.add('show');
  setTimeout(function() {
    var inp = document.getElementById('modal-prompt-input');
    if (inp) { inp.focus(); inp.select(); }
  }, 100);
}

function showModal(title, content, buttons) {
  var ov = document.getElementById('modal-overlay');
  document.getElementById('modal-title').textContent = title;
  document.getElementById('modal-title').className = '';
  document.getElementById('modal-sub').innerHTML = content;
  var bt = document.getElementById('modal-buttons'); bt.innerHTML = '';
  (buttons || []).forEach(function(btn) {
    var el = document.createElement('button');
    el.className = 'modal-btn' + (btn.className ? ' ' + btn.className : '');
    el.textContent = btn.text;
    el.onclick = function() { if (btn.onClick) btn.onClick(); };
    bt.appendChild(el);
  });
  ov.classList.add('show');
}

function closeModal() {
  var ov = document.getElementById('modal-overlay');
  ov.classList.remove('show');
}
