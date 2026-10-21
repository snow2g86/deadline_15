#!/usr/bin/env python3
"""6b: 내보낸 iOS Xcode 프로젝트(godot/build/ios)를 손질한다 — 표준 라이브러리만 사용, 받은 스크립트는 쓰지 않음.

  python3 godot/tools/ios_post_export.py godot/build/ios        (tools/ios_export.sh 가 내보낸 직후 부름)

  1) Info.plist: 빈 사용 설명 키(카메라·사진·마이크) 지움 (6a ios_fix_plist.sh 와 같음) · CFBundleLocalizations(6개 언어) · NSUserTrackingUsageDescription 확인
  2) <언어>.lproj/InfoPlist.strings 6개 — 광고 추적 허용(ATT) 문구 현지화 (tools/ios_privacy_strings.json) + pbxproj 의 변형 그룹·knownRegions
  3) godot-iap 프레임워크 2개(GodotIap · SwiftGodotRuntime): Godot 4.5.1 은 안의 실행 파일만 링크 항목으로 넣으므로 .framework 폴더를 'Embed Frameworks'(서명하며 복사)로 바꾸고 Info.plist 를 되돌려 넣음
  4) AdMob SPM 패키지(Google Mobile Ads 13.9.0 · UMP 3.1.0): 플러그인이 만든 admob_spm 를 pbxproj 에 연결 (플러그인 자신의 연결은 헤드리스 내보내기가 끝나기 전에 실행되지 못함)
  5) In-App Purchase 기능(SystemCapabilities com.apple.InAppPurchase) 켬 — 서명 때 Xcode 가 App ID 와 맞춤
  6) 임시 팀 ID(AAAAAAAAAA)를 비움 — 서명은 사용자가 Xcode 에서
"""
import hashlib, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.dirname(HERE)
LPROJ = {"en": "en", "ko": "ko", "ja": "ja", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant", "es": "es"}
FRAMEWORKS = ["GodotIap", "SwiftGodotRuntime"]
TEMP_TEAM = "AAAAAAAAAA"


def hid(seed):
    return hashlib.md5(seed.encode()).hexdigest().upper()[:24]


def main(root):
    projs = [d for d in os.listdir(root) if d.endswith(".xcodeproj")]
    if len(projs) != 1:
        sys.exit("xcodeproj 가 하나여야 함: %s" % projs)
    name = projs[0][:-len(".xcodeproj")]
    app = os.path.join(root, name)
    pbx_path = os.path.join(root, projs[0], "project.pbxproj")
    pl_path = os.path.join(app, name + "-Info.plist")
    strings = json.load(open(os.path.join(HERE, "ios_privacy_strings.json"), encoding="utf-8"))
    pbx = open(pbx_path, encoding="utf-8").read()
    pl = open(pl_path, encoding="utf-8").read()

    # 1) Info.plist
    for k in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription", "NSMicrophoneUsageDescription"):
        pl = re.sub(r"\n\t<key>%s</key>\n\t<string></string>" % k, "", pl)
    if "CFBundleLocalizations" not in pl:
        arr = "".join("\n\t\t<string>%s</string>" % c for c in LPROJ)
        pl = pl.replace("\t<key>CFBundleDevelopmentRegion</key>\n\t<string>en</string>",
                        "\t<key>CFBundleDevelopmentRegion</key>\n\t<string>en</string>\n\t<key>CFBundleLocalizations</key>\n\t<array>%s\n\t</array>" % arr, 1)
    for need in ("GADApplicationIdentifier", "NSUserTrackingUsageDescription", "SKAdNetworkItems"):
        if need not in pl:
            sys.exit("Info.plist 에 %s 가 없음 — 내보내기 설정(앱 ID · additional_plist_content)을 확인" % need)
    open(pl_path, "w", encoding="utf-8").write(pl)

    # 2) 현지화 문구
    refs, kids = [], []
    for code in LPROJ:
        d = os.path.join(app, code + ".lproj")
        os.makedirs(d, exist_ok=True)
        f = os.path.join(d, "InfoPlist.strings")
        base = open(f, encoding="utf-8").read() if os.path.exists(f) else "/* Localized versions of Info.plist keys */\n"
        base = re.sub(r'\n?"NSUserTrackingUsageDescription" = ".*";\n?', "\n", base)
        txt = strings[code].replace("\\", "\\\\").replace('"', '\\"')
        open(f, "w", encoding="utf-8").write(base.rstrip("\n") + '\n"NSUserTrackingUsageDescription" = "%s";\n' % txt)
        if code != "en" and ("name = %s;" % code) not in pbx:
            rid = hid("strings_" + code)
            refs.append('\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = "%s"; path = "%s.lproj/InfoPlist.strings"; sourceTree = "<group>"; };\n' % (rid, code, code, code))
            kids.append("\t\t\t\t%s /* %s */,\n" % (rid, code))
    if refs:
        pbx = pbx.replace("/* End PBXFileReference section */", "".join(refs) + "/* End PBXFileReference section */", 1)
        m = re.search(r"(isa = PBXVariantGroup;\s*children = \(\n)(.*?)(\s*\);\s*name = InfoPlist\.strings;)", pbx, re.S)
        if not m:
            sys.exit("InfoPlist.strings 변형 그룹을 찾지 못함")
        pbx = pbx[:m.end(2)] + "\n" + "".join(kids).rstrip("\n") + pbx[m.end(2):]
        regions = "".join("\t\t\t\t%s,\n" % c for c in LPROJ if c != "en")
        pbx = re.sub(r"(knownRegions = \(\n\t\t\t\ten,\n)", r"\1" + regions, pbx, count=1) if "ko," not in pbx else pbx

    # 3) godot-iap 프레임워크
    for fw in FRAMEWORKS:
        src_plist = os.path.join(GODOT, "third_party", "godot-iap-ios", "bin", "ios", fw + ".framework", "Info.plist")
        dst_dir = os.path.join(app, "addons", "godot-iap", "bin", "ios", fw + ".framework")
        if os.path.isdir(dst_dir) and os.path.exists(src_plist):
            open(os.path.join(dst_dir, "Info.plist"), "wb").write(open(src_plist, "rb").read())
        m = re.search(r'(\w{24}) = \{isa = PBXFileReference; lastKnownFileType = file; name = "%s"; path = "([^"]*/%s\.framework)/%s"; sourceTree = "<group>"; \};' % (fw, fw, fw), pbx)
        if not m:
            if ('name = "%s.framework"' % fw) in pbx:
                continue   # 이미 손질됨
            sys.exit("%s 프레임워크 참조를 찾지 못함" % fw)
        ref = m.group(1)
        pbx = pbx.replace(m.group(0), '%s = {isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = "%s.framework"; path = "%s"; sourceTree = "<group>"; };' % (ref, fw, m.group(2)))
        bm = re.search(r"(\w{24}) = \{isa = PBXBuildFile; fileRef = %s; \};" % ref, pbx)
        bid = bm.group(1)
        pbx = pbx.replace(bm.group(0), "%s /* %s.framework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = %s; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };" % (bid, fw, ref))
        # 링크 단계(Frameworks)에서 빼고 Embed Frameworks 에 넣음
        fm = re.search(r"(isa = PBXFrameworksBuildPhase;.*?files = \(\n)(.*?)(\n\s*\);)", pbx, re.S)
        block = fm.group(2)
        block2 = re.sub(r"[ \t]*%s,?\n?" % bid, "", block)
        block2 = block2.rstrip()
        pbx = pbx[:fm.start(2)] + block2 + pbx[fm.end(2):]
        em = re.search(r"(/\* Embed Frameworks \*/ = \{\s*isa = PBXCopyFilesBuildPhase;.*?files = \(\n)(.*?)(\n\s*\);)", pbx, re.S)
        pbx = pbx[:em.end(2)] + "\n\t\t\t\t%s /* %s.framework in Embed Frameworks */," % (bid, fw) + pbx[em.end(2):]

    # 4) AdMob SPM
    spm = os.path.join(root, "admob_spm", "Package.swift")
    if os.path.exists(spm) and "AD0000000000000000000001" not in pbx:
        lr, pd, bf = "AD0000000000000000000001", "AD0000000000000000000002", "AD0000000000000000000003"
        pbx = pbx.replace("/* End PBXGroup section */", "/* End PBXGroup section */\n\n/* Begin XCLocalSwiftPackageReference section */\n\t\t%s /* XCLocalSwiftPackageReference \"admob_spm\" */ = {\n\t\t\tisa = XCLocalSwiftPackageReference;\n\t\t\trelativePath = \"admob_spm\";\n\t\t};\n/* End XCLocalSwiftPackageReference section */\n\n/* Begin XCSwiftPackageProductDependency section */\n\t\t%s /* PoingGodotAdMobDeps */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = %s /* XCLocalSwiftPackageReference \"admob_spm\" */;\n\t\t\tproductName = \"PoingGodotAdMobDeps\";\n\t\t};\n/* End XCSwiftPackageProductDependency section */" % (lr, pd, lr), 1)
        pbx = pbx.replace("/* Begin PBXBuildFile section */", "/* Begin PBXBuildFile section */\n\t\t%s /* PoingGodotAdMobDeps in Frameworks */ = {isa = PBXBuildFile; productRef = %s /* PoingGodotAdMobDeps */; };" % (bf, pd), 1)
        pbx = pbx.replace("productRefGroup =", "packageReferences = (\n\t\t\t\t%s /* XCLocalSwiftPackageReference \"admob_spm\" */,\n\t\t\t);\n\t\t\tproductRefGroup =" % lr, 1)
        pbx = pbx.replace("buildRules = (", "packageProductDependencies = (\n\t\t\t\t%s /* PoingGodotAdMobDeps */,\n\t\t\t);\n\t\t\tbuildRules = (" % pd, 1)
        i = pbx.index("isa = PBXFrameworksBuildPhase;")
        j = pbx.index("files = (", i) + len("files = (")
        pbx = pbx[:j] + "\n\t\t\t\t%s /* PoingGodotAdMobDeps in Frameworks */," % bf + pbx[j:]

    # 5) In-App Purchase 기능
    pbx = pbx.replace("SystemCapabilities = {\n\t\t\t\t\t\t};", "SystemCapabilities = {\n\t\t\t\t\t\t\tcom.apple.InAppPurchase = {\n\t\t\t\t\t\t\t\tenabled = 1;\n\t\t\t\t\t\t\t};\n\t\t\t\t\t\t};")

    # 6) 임시 팀 ID 비움
    pbx = pbx.replace("DEVELOPMENT_TEAM = %s;" % TEMP_TEAM, 'DEVELOPMENT_TEAM = "";').replace("DevelopmentTeam = %s;" % TEMP_TEAM, 'DevelopmentTeam = "";')
    open(pbx_path, "w", encoding="utf-8").write(pbx)
    eo = os.path.join(app, "export_options.plist")
    if os.path.exists(eo):
        t = open(eo, encoding="utf-8").read().replace(TEMP_TEAM, "")
        open(eo, "w", encoding="utf-8").write(t)

    for p in (pl_path, os.path.join(app, "export_options.plist")):
        if os.path.exists(p):
            subprocess.run(["plutil", "-lint", p], check=True, stdout=subprocess.DEVNULL)
    r = subprocess.run(["xcodebuild", "-list", "-project", os.path.join(root, projs[0])], capture_output=True, text=True)   # pbxproj 가 Xcode 에서 읽히는지
    print("ios_post_export: %s — xcodebuild -list %s" % (name, "OK" if r.returncode == 0 else r.stdout[-600:] + r.stderr[-600:]))
    if r.returncode != 0:
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(GODOT, "build", "ios"))
