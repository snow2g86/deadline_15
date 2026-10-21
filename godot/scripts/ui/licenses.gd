extends "res://scripts/ui/info_page.gd"
## 오픈 소스 라이선스 — 웹 licenses.html (4b-2) + Godot 판에 필요한 것
##  - Noto Sans KR · JP · SC · TC (Google, SIL OFL 1.1) — godot/assets/fonts/OFL.txt 전체 글 (펼치기)
##  - Godot Engine (MIT/Expat) — Engine.get_license_text() 전체 글
##  - (4b-2) V8 (BSD-3-Clause) — js.gd 의 V8 정렬·36진수 표기 이식
##  - Godot 에 들어 있는 제3자 구성 요소 — Engine.get_copyright_info() (이름 · 저작권 · 라이선스), 라이선스 전체 글 Engine.get_license_info() (펼치기)
##  - (6b) 모바일 결제·광고: 플러그인 3종(Godot Google Play Billing · Poing Studios AdMob · godot-iap/OpenIAP, 모두 MIT) + SwiftGodot 런타임(MIT, iOS 판에 들어감) +
##    Google SDK(Play Billing Library · Mobile Ads SDK · User Messaging Platform — Google LLC, 각 약관) + AndroidX·Kotlin(Apache 2.0). godot/addons/SOURCES.md 와 같은 목록
##  웹의 Cinzel 글꼴은 Godot 판이 쓰지 않아 뺌 (godot/assets/fonts 에 없음). 라이선스 글 자체는 번역하지 않음 (법적 원문). 아래 글은 웹과 같음.
##  내보내기 때 assets/fonts/OFL.txt 를 넣어야 함 (godot/README.md '내보내기')

const OFL_PATH := "res://assets/fonts/OFL.txt"
## (4b-2) scripts/logic/js.gd 의 v8_sort(V8 builtins/array-sort.tq)·frac_to_base36/rand36_4(V8 DoubleToRadixCString) 이식 — V8 LICENSE (BSD-3-Clause) 원문
const V8_LICENSE := """Copyright 2006-2018, the V8 project authors. All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of Google Inc. nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."""


## (6b) 플러그인 3종 + SwiftGodot 의 MIT 본문 (저작권 줄만 다르고 본문은 같음 — addons/*/LICENSE 와 SwiftGodot THIRD_PARTY_NOTICES)
const MIT_BODY := """Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""
## [이름, 버전 줄, 저작권 줄] — 모두 MIT License
const MIT_ITEMS := [
	["Godot Google Play Billing (plugin)", "GodotGooglePlayBilling 3.3.0 — github.com/godot-sdk-integrations/godot-google-play-billing", "Copyright (c) 2020 Godot Engine contributors"],
	["Godot AdMob Plugin", "Poing Studios, 5.1.0 — github.com/poingstudios/godot-admob-plugin", "Copyright (c) 2020-present Poing Studios"],
	["godot-iap (OpenIAP)", "4.0.3 — github.com/hyodotdev/openiap", "Copyright (c) 2025 hyo.dev"],
	["SwiftGodot Runtime", "Bundled with godot-iap (iOS) — github.com/migueldeicaza/SwiftGodot", "Copyright (c) 2020-2024 Miguel de Icaza"],
]
const APACHE_NOTICE := """Licensed under the Apache License, Version 2.0 (the "License"); you may not use these libraries except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License."""


func page_id() -> String:
	return "licenses"


func title_text() -> String:
	return t("settings.licenses")


func fill() -> void:
	var fonts := section("Noto")
	_head(fonts, "Noto Sans KR · Noto Sans JP · Noto Sans SC · Noto Sans TC", "Google", "SIL Open Font License 1.1")
	fonts.add_child(wrap_label("This Font Software is licensed under the SIL Open Font License, Version 1.1. This license is available with a FAQ at: https://scripts.sil.org/OFL", 11, OKit.DIM2))
	_expander(fonts, "OflText", FileAccess.get_file_as_string(OFL_PATH) if FileAccess.file_exists(OFL_PATH) else "")
	var gd := section("Godot")
	var ci: Array = Engine.get_copyright_info()
	var who := "Godot Engine contributors"
	if not ci.is_empty() and str(ci[0].get("name", "")) == "Godot Engine":
		who = "; ".join(PackedStringArray(ci[0]["parts"][0].get("copyright", [])))
	_head(gd, "Godot Engine", who, "MIT License")
	gd.add_child(wrap_label(t("gd.licenses.godot_note"), 11, OKit.DIM2))
	_expander(gd, "GodotText", Engine.get_license_text())
	var v8 := section("V8")
	_head(v8, "V8 JavaScript Engine", "Copyright 2006-2018, the V8 project authors", "BSD 3-Clause License")
	v8.add_child(wrap_label(t("gd.licenses.v8_note"), 11, OKit.DIM2))
	_expander(v8, "V8Text", V8_LICENSE)
	# (6b) 모바일 결제·광고 구성 요소
	var mb := section("Mobile")
	_head(mb, t("gd.licenses.mobile_title"), "", "")
	mb.add_child(wrap_label(t("gd.licenses.mobile_note"), 11, OKit.DIM2))
	var mi := 0
	for it: Array in MIT_ITEMS:
		var row := OKit.vbox(3)
		row.name = "MobileMit%d" % mi
		mi += 1
		mb.add_child(row)
		_head(row, str(it[0]), str(it[2]), "MIT License")
		row.add_child(wrap_label(str(it[1]), 10, OKit.DIM2))
		_expander(row, "Text", str(it[2]) + "\n\n" + MIT_BODY)
	var gs := OKit.vbox(3)
	gs.name = "MobileGoogle"
	mb.add_child(gs)
	_head(gs, "Google Play Billing Library · Google Mobile Ads SDK · Google User Messaging Platform", "© Google LLC", "")
	gs.add_child(wrap_label(t("gd.licenses.google_note"), 11, OKit.DIM2))
	var ap := OKit.vbox(3)
	ap.name = "MobileApache"
	mb.add_child(ap)
	_head(ap, "AndroidX · Kotlin", "", "Apache License 2.0")
	ap.add_child(wrap_label(t("gd.licenses.apache_note"), 11, OKit.DIM2))
	_expander(ap, "Text", APACHE_NOTICE)
	var tp := section("ThirdParty")
	_head(tp, t("gd.licenses.third_party"), "Godot Engine", "")
	tp.add_child(wrap_label(t("gd.licenses.third_party_note"), 11, OKit.DIM2))
	var lines: Array = []
	for comp: Dictionary in ci:
		if str(comp.get("name", "")) == "Godot Engine":
			continue
		var lic: Array = []
		var cr: Array = []
		for part: Dictionary in comp.get("parts", []):
			if not lic.has(str(part.get("license", ""))):
				lic.append(str(part.get("license", "")))
			for line: Variant in part.get("copyright", []):
				if not cr.has(str(line)):
					cr.append(str(line))
		lines.append("%s — %s\n  © %s" % [comp["name"], ", ".join(lic), "; ".join(cr)])
	_expander(tp, "Components", "\n".join(lines))
	var li: Dictionary = Engine.get_license_info()
	for k: String in li.keys():
		var row := OKit.vbox(2)
		row.name = "Lic_" + k
		var kl := OKit.label(12, OKit.TEXT, 800)
		kl.text = k
		row.add_child(kl)
		_expander(row, "Text", str(li[k]))
		tp.add_child(row)
	footer("DEADLINE 15 © 2026 show4you · MIT License")


func _head(v: VBoxContainer, name: String, author: String, kind: String) -> void:
	v.add_child(wrap_label(name, 15, OKit.TEXT, 900))
	if author != "":
		v.add_child(wrap_label(author, 11, OKit.DIM, 500))
	if kind != "":
		var p := OKit.pill(kind, 10, Color("4ade80"), Color(74 / 255.0, 222 / 255.0, 128 / 255.0, 0.1), Color(0, 0, 0, 0), 700)
		p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(p)


## 전체 글 펼치기·접기 단추 + 글 (처음엔 접힘)
func _expander(v: Control, nm: String, text: String) -> void:
	if text == "":
		return
	var b := OKit.ghost_button("", 11, Color("60a5fa"))
	b.name = nm + "Btn"
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var l := OKit.label(10, OKit.DIM2, 400)
	l.name = nm
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(COL_W - 40.0, 0)
	l.visible = false
	var upd := func() -> void: b.text = t("gd.licenses.hide") if l.visible else t("gd.licenses.show")
	b.pressed.connect(func() -> void:
		l.visible = not l.visible
		upd.call())
	upd.call()
	v.add_child(b)
	v.add_child(l)
