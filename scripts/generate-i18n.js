#!/usr/bin/env node
/**
 * generate-i18n.js - i18n-data.js 자동 생성 스크립트
 *
 * skills.js와 classes.js에서 게임 데이터를 추출하여
 * i18n-data.js의 skills, classes 섹션을 자동으로 업데이트합니다.
 *
 * 사용법:
 *   node scripts/generate-i18n.js
 */

const fs = require('fs');
const path = require('path');

// 파일 경로
const skillsPath = path.join(__dirname, '../js/skills.js');
const classesPath = path.join(__dirname, '../js/classes.js');
const i18nPath = path.join(__dirname, '../js/i18n-data.js');

// ═══════════════════════════════════════════════════════════
// 1. SKILLS 데이터 추출
// ═══════════════════════════════════════════════════════════
function extractSkills() {
  const content = fs.readFileSync(skillsPath, 'utf-8');
  const skills = {};

  // const SKILLS = { ... } 패턴 찾기
  const skillsMatch = content.match(/const\s+SKILLS\s*=\s*\{([\s\S]*?)\n\};/);
  if (!skillsMatch) {
    console.error('❌ SKILLS 객체를 찾을 수 없습니다');
    process.exit(1);
  }

  const skillsContent = skillsMatch[1];

  // 각 클래스별 스킬 추출
  // 패턴: id: 'value', name: 'value' (작은따옴표 사용)
  const skillPattern = /id:\s*'([^']+)'[^}]*?name:\s*'([^']+)'/g;
  let match;

  while ((match = skillPattern.exec(skillsContent)) !== null) {
    const id = match[1];
    const name = match[2];
    skills[id] = name;
  }

  return skills;
}

// ═══════════════════════════════════════════════════════════
// 2. CD (Classes) 데이터 추출
// ═══════════════════════════════════════════════════════════
function extractClasses() {
  const content = fs.readFileSync(classesPath, 'utf-8');
  const classes = {};

  // const CD = { ... } 패턴 찾기
  const cdMatch = content.match(/const\s+CD\s*=\s*\{([\s\S]*?)\n\};/);
  if (!cdMatch) {
    console.error('❌ CD 객체를 찾을 수 없습니다');
    process.exit(1);
  }

  const cdContent = cdMatch[1];

  // 각 직업별 이름 추출
  // 패턴: "classname": { name: "value", ...
  const classPattern = /(\w+):\s*\{[^}]*?name:'([^']+)'/g;
  let match;

  while ((match = classPattern.exec(cdContent)) !== null) {
    const cls = match[1];
    const name = match[2];
    classes[cls] = name;
  }

  return classes;
}

// ═══════════════════════════════════════════════════════════
// 3. i18n-data.js 읽기
// ═══════════════════════════════════════════════════════════
function readI18nData() {
  const content = fs.readFileSync(i18nPath, 'utf-8');
  return content;
}

// ═══════════════════════════════════════════════════════════
// 4. 한국어 skills 섹션 생성
// ═══════════════════════════════════════════════════════════
function generateSkillsKo(extractedSkills, existingData) {
  // 기존 한국어 skills 섹션 추출
  const koSkillsMatch = existingData.match(/"ko":\s*\{[\s\S]*?"skills":\s*\{([\s\S]*?)\},/);
  const existingSkills = {};

  if (koSkillsMatch) {
    const skillLines = koSkillsMatch[1].match(/"([^"]+)":\s*"([^"]+)"/g) || [];
    skillLines.forEach(line => {
      const match = line.match(/"([^"]+)":\s*"([^"]+)"/);
      if (match) existingSkills[match[1]] = match[2];
    });
  }

  // 기존 번역 유지하고 새 스킬 추가
  const merged = { ...extractedSkills, ...existingSkills };
  const entries = Object.entries(merged)
    .sort(([a], [b]) => a.localeCompare(b));

  return entries.map(([id, name]) => `      "${id}": "${name}"`).join(',\n');
}

// ═══════════════════════════════════════════════════════════
// 5. 한국어 classes 섹션 생성
// ═══════════════════════════════════════════════════════════
function generateClassesKo(extractedClasses, existingData) {
  // 기존 한국어 classes 섹션 추출
  const koClassesMatch = existingData.match(/"ko":\s*\{[\s\S]*?"classes":\s*\{([\s\S]*?)\},/);
  const existingClasses = {};

  if (koClassesMatch) {
    const classLines = koClassesMatch[1].match(/"([^"]+)":\s*"([^"]+)"/g) || [];
    classLines.forEach(line => {
      const match = line.match(/"([^"]+)":\s*"([^"]+)"/);
      if (match) existingClasses[match[1]] = match[2];
    });
  }

  // 기존 번역 유지하고 새 직업 추가
  const merged = { ...extractedClasses, ...existingClasses };
  const entries = Object.entries(merged)
    .sort(([a], [b]) => a.localeCompare(b));

  return entries.map(([cls, name]) => `      "${cls}": "${name}"`).join(',\n');
}

// ═══════════════════════════════════════════════════════════
// 6. 영어 skills 섹션 생성
// ═══════════════════════════════════════════════════════════
function generateSkillsEn(extractedSkills, existingData) {
  // 기존 영어 skills 섹션 추출
  const enSkillsMatch = existingData.match(/"en":\s*\{[\s\S]*?"skills":\s*\{([\s\S]*?)\},/);
  const existingSkills = {};

  if (enSkillsMatch) {
    const skillLines = enSkillsMatch[1].match(/"([^"]+)":\s*"([^"]+)"/g) || [];
    skillLines.forEach(line => {
      const match = line.match(/"([^"]+)":\s*"([^"]+)"/);
      if (match) existingSkills[match[1]] = match[2];
    });
  }

  // 기존 번역 유지, 없으면 [미번역] 표시
  const entries = Object.keys(extractedSkills)
    .sort()
    .map(id => `      "${id}": "${existingSkills[id] || '[TODO: Translate]'}"`)
    .join(',\n');

  return entries;
}

// ═══════════════════════════════════════════════════════════
// 7. 영어 classes 섹션 생성
// ═══════════════════════════════════════════════════════════
function generateClassesEn(extractedClasses, existingData) {
  // 기존 영어 classes 섹션 추출
  const enClassesMatch = existingData.match(/"en":\s*\{[\s\S]*?"classes":\s*\{([\s\S]*?)\},/);
  const existingClasses = {};

  if (enClassesMatch) {
    const classLines = enClassesMatch[1].match(/"([^"]+)":\s*"([^"]+)"/g) || [];
    classLines.forEach(line => {
      const match = line.match(/"([^"]+)":\s*"([^"]+)"/);
      if (match) existingClasses[match[1]] = match[2];
    });
  }

  // 기존 번역 유지, 없으면 [미번역] 표시
  const entries = Object.keys(extractedClasses)
    .sort()
    .map(cls => `      "${cls}": "${existingClasses[cls] || '[TODO: Translate]'}"`)
    .join(',\n');

  return entries;
}

// ═══════════════════════════════════════════════════════════
// 8. 스페인어도 동일 처리
// ═══════════════════════════════════════════════════════════
function generateSkillsEs(extractedSkills, existingData) {
  const esSkillsMatch = existingData.match(/"es":\s*\{[\s\S]*?"skills":\s*\{([\s\S]*?)\},/);
  const existingSkills = {};

  if (esSkillsMatch) {
    const skillLines = esSkillsMatch[1].match(/"([^"]+)":\s*"([^"]+)"/g) || [];
    skillLines.forEach(line => {
      const match = line.match(/"([^"]+)":\s*"([^"]+)"/);
      if (match) existingSkills[match[1]] = match[2];
    });
  }

  const entries = Object.keys(extractedSkills)
    .sort()
    .map(id => `      "${id}": "${existingSkills[id] || '[TODO: Traducir]'}"`)
    .join(',\n');

  return entries;
}

function generateClassesEs(extractedClasses, existingData) {
  const esClassesMatch = existingData.match(/"es":\s*\{[\s\S]*?"classes":\s*\{([\s\S]*?)\},/);
  const existingClasses = {};

  if (esClassesMatch) {
    const classLines = esClassesMatch[1].match(/"([^"]+)":\s*"([^"]+)"/g) || [];
    classLines.forEach(line => {
      const match = line.match(/"([^"]+)":\s*"([^"]+)"/);
      if (match) existingClasses[match[1]] = match[2];
    });
  }

  const entries = Object.keys(extractedClasses)
    .sort()
    .map(cls => `      "${cls}": "${existingClasses[cls] || '[TODO: Traducir]'}"`)
    .join(',\n');

  return entries;
}

// ═══════════════════════════════════════════════════════════
// 메인 실행
// ═══════════════════════════════════════════════════════════
console.log('🔄 i18n-data.js 생성 중...\n');

const skills = extractSkills();
const classes = extractClasses();
const existingData = readI18nData();

console.log(`✅ 추출된 스킬: ${Object.keys(skills).length}개`);
console.log(`✅ 추출된 직업: ${Object.keys(classes).length}개\n`);

const skillsKo = generateSkillsKo(skills, existingData);
const classesKo = generateClassesKo(classes, existingData);
const skillsEn = generateSkillsEn(skills, existingData);
const classesEn = generateClassesEn(classes, existingData);
const skillsEs = generateSkillsEs(skills, existingData);
const classesEs = generateClassesEs(classes, existingData);

// i18n-data.js 업데이트 (정규식으로 섹션 치환)
let updated = existingData;

// 한국어 skills 섹션 교체
updated = updated.replace(
  /("ko":\s*\{[\s\S]*?"skills":\s*\{)([\s\S]*?)(\},)/,
  `$1\n${skillsKo}\n    $3`
);

// 한국어 classes 섹션 교체
updated = updated.replace(
  /("ko":\s*\{[\s\S]*?"classes":\s*\{)([\s\S]*?)(\},)/,
  `$1\n${classesKo}\n    $3`
);

// 영어 skills 섹션 교체
updated = updated.replace(
  /("en":\s*\{[\s\S]*?"skills":\s*\{)([\s\S]*?)(\},)/,
  `$1\n${skillsEn}\n    $3`
);

// 영어 classes 섹션 교체
updated = updated.replace(
  /("en":\s*\{[\s\S]*?"classes":\s*\{)([\s\S]*?)(\},)/,
  `$1\n${classesEn}\n    $3`
);

// 스페인어 skills 섹션 교체
updated = updated.replace(
  /("es":\s*\{[\s\S]*?"skills":\s*\{)([\s\S]*?)(\},)/,
  `$1\n${skillsEs}\n    $3`
);

// 스페인어 classes 섹션 교체
updated = updated.replace(
  /("es":\s*\{[\s\S]*?"classes":\s*\{)([\s\S]*?)(\},)/,
  `$1\n${classesEs}\n    $3`
);

fs.writeFileSync(i18nPath, updated, 'utf-8');

console.log('✅ i18n-data.js 업데이트 완료!\n');
console.log('📝 다음 단계:');
console.log('   1. 영어/스페인어 [TODO] 항목을 번역하세요');
console.log('   2. 변경사항을 커밋하세요');
console.log('   3. 새 스킬/직업 추가 시 다시 스크립트를 실행하세요\n');
