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
