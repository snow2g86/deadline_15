# DEADLINE 15 Privacy Policy (Draft)

> **This is a draft and is not a substitute for legal advice.** Before publishing, have a qualified professional check it against the laws that apply to you (for example Korea's Personal Information Protection Act, GDPR, CCPA/CPRA, COPPA).
> `[확인 필요]` ("needs confirmation") marks parts you must fill in or verify. The facts were read from the code and docs as of 2026-10-23 (`godot/README.md` section 6b, `docs/server/api.md`, `server/README.md`, `godot/data/iap.json`).
> When you turn this into the published version, remove this note block and every `[확인 필요]` marker.

Effective date: [확인 필요: effective date, for example "October 1, 2026"]
Last updated: [확인 필요]

**[Developer display name [확인 필요]]** ("we", "us") provides the mobile and PC game "DEADLINE 15" (package / bundle ID `xyz.show4you.deadline15`, the "App"). This policy explains what information the App handles and why.

## 1. What the App does not do

- There are no accounts or sign-ups. We do not ask for your name, email, phone number, address or date of birth.
- We do not collect precise location, contacts, photos, microphone or camera data (the App does not request those permissions).
- There is no chat between players and no user-generated content.
- Your game progress (clan members, gold, equipment, stage records, settings) is stored **only on your device** and is not sent to our server.

## 2. Information we handle

| Category | Items | When | Purpose | Who receives it |
|---|---|---|---|---|
| Install ID | A random identifier (128-bit random number, not a value that identifies you personally) that the App creates the first time it verifies a purchase and keeps in its save file | Sent to our server with each purchase verification, consumption and refund check | Verify purchase receipts, prevent duplicate delivery, apply refunds | Our purchase verification server (run on Cloudflare) |
| Purchase information | Store order number, product ID (which gold package), purchase time, status (verified, consumed, refunded), and a hash (SHA-256) of the receipt value. We do not store the original receipt; we only ask the store to confirm it | When you buy a gold package | Confirm purchases, handle refunds and disputes, keep records required by law | The verification server, and Google Play / Apple / STOVE, which answer the confirmation request |
| Store account value | Google Play: an obfuscated value made from the install ID (first 32 characters of `SHA-256(install ID)`). App Store: an account token made the same way. STOVE (PC): the member number hashed with a server secret key. These are not your name or email | When you buy | Purchase records and dispute handling | Google / Apple / the verification server |
| Server access log | Request path, response status, error code and processing time. Receipts, tokens and secrets are not written to the log | When the App contacts the server | Troubleshooting, abuse prevention | The verification server (Cloudflare) |
| Network information (IP address) | Cloudflare infrastructure processes the IP address for rate limiting (abuse prevention) [확인 필요: actual retention and logging settings] | When the App contacts the server | Abuse prevention, service stability | Cloudflare |
| Ad-related information (mobile ad edition only) | Advertising identifier (Android Advertising ID / iOS IDFA, iOS only if you allow tracking), approximate location estimated from the IP address, device and app information, ad interactions, crash and performance diagnostics [확인 필요: compare with Google's official AdMob disclosure] | When ads are loaded and shown | Serve and measure ads, prevent fraud | Google AdMob (the ad SDK collects and processes it directly) |
| Ad consent choice | The choice you make in the ad privacy consent dialog, where one applies (for example the EEA) | At app start | Record consent, decide whether ads can be requested | Stored on your device; Google's User Messaging Platform (UMP) |

- **The PC (STOVE) edition has no ads** and does not process ad-related information. Information needed for STOVE login and payment is handled by STOVE under its own policy.
- The App does not include separate analytics or crash-reporting tools [확인 필요: final check that no other SDK was added to the release build]. Diagnostics collected by the ad SDK are included in the table above.

## 3. Why we use it

1. Verify in-app purchases (gold packages) and deliver gold
2. Apply refunded or cancelled purchases; prevent duplicate delivery and fraudulent purchases
3. Provide rewarded ads (mobile): finishing an ad grants 100 gold (up to 3 times a day)
4. Keep the service stable and prevent abuse
5. Keep records required by law and handle disputes

## 4. Retention and deletion

| Information | Kept | How to delete |
|---|---|---|
| Game data and install ID on your device | Until you uninstall the App or clear its data | Uninstall the App or clear its data in your device settings (the in-game "reset all data" does not erase the purchase record or install ID) [확인 필요: wording for users] |
| Purchase records on the server (install ID, order number, product, time, status) | **5 years** from purchase, following the record-keeping period used in Korean e-commerce law [확인 필요: confirm the legal period] | Deleted automatically after 5 years. When deleting, we may keep only a one-way hash (SHA-256) of "store + order number" so the same receipt cannot be redeemed again; it cannot identify you |
| Server access log | According to Cloudflare's default retention [확인 필요: log retention setting] | Deleted automatically at the end of that period |
| Ad information | According to Google's policies | Reset or delete your device advertising ID, change consent in the App's "Ad privacy settings", or use Google's ad settings |

If you uninstall and reinstall, a new install ID is created. Server records tied to the old install ID remain for the period above and are not linked to the new one. (There is one exception: so that a legitimate purchase that was not yet delivered can be recovered, ownership of an order can be moved once to the new install within a limited time.)

## 5. Sharing and service providers

| Recipient | Purpose | Information | Location (cross-border transfer) |
|---|---|---|---|
| Google (Google LLC, Google Ireland Ltd. and others): Google AdMob | Serve and measure rewarded ads | Advertising identifier, approximate location (IP-based), device and app information, ad interactions, diagnostics | United States and others [확인 필요: transfer notice requirements] |
| Google (Google Play) | Process Android in-app purchases and confirm receipts | Purchase token and order number, obfuscated account value | United States and others |
| Apple (App Store) | Process iOS in-app purchases and confirm receipts | Transaction information (signed transactions), account token | United States and others |
| STOVE (Smilegate) | PC login and payments | Handled by STOVE under its own policy; we receive a hashed member number and purchase information [확인 필요: update after the STOVE integration is finalized] | Korea [확인 필요] |
| Cloudflare, Inc. | Run the purchase verification server (Workers and D1 database) | Install ID, purchase information, server access log | Data centers worldwide [확인 필요: data storage location] |

- We do not sell personal information.
- Except where the law requires it, we do not provide information to third parties outside the purposes above.
- These third parties process information under their own privacy policies (Google: policies.google.com/privacy, Apple: apple.com/legal/privacy, STOVE, Cloudflare: cloudflare.com/privacypolicy).

## 6. Ads and consent (mobile)

- Ads are provided by Google AdMob. The App is not directed at children, so child-directed ad treatment (`tag_for_child_directed_treatment`) is not applied.
- In regions where consent is required, such as the European Economic Area and the UK, Google's User Messaging Platform (UMP) shows an ad privacy consent dialog at app start. Ads are not requested until the consent status is known.
- You can review or change your choice in the App under "Settings > Ad privacy settings" (where applicable to your region).
- On iOS you may be asked for permission to use the advertising identifier (IDFA). The game plays exactly the same if you decline.
- You can play without watching ads.

## 7. Children

The App is not directed at children under 14 (Korea) or under 13 (US), and we do not knowingly collect their personal information. The App has no accounts and does not take names or contact details. If a parent or guardian believes a child's information has been processed, please contact us below. [확인 필요: reflect the target-age decision (checklist section 0) and the policy for under-14 users]

## 8. Your rights and how to use them

You may ask to access, correct, delete or restrict the processing of your personal information.

- The App holds no information that directly identifies you, so to find a server record we need the **store order number** from your receipt (a Google Play order number such as `GPA.…`, or an Apple transaction ID).
- How to ask: [privacy contact email [확인 필요]]
- We handle requests without undue delay after verifying them [확인 필요: response-time wording, for example "within 10 days"]. Records we must keep by law may not be deleted during the retention period.
- Ad-related information can be managed in your device's ad settings and in Google's ad settings.

## 9. Security

- Communication between the App and our server uses HTTPS only (release builds).
- The App contains no server secret keys. Server secrets are kept only in the server's secure secret storage.
- We do not write original receipts or tokens to server records; we store only hashes.
- Rate limiting and input checks limit abuse.
- Only people with access rights can reach the server database.

## 10. Regional notes [확인 필요: legal review]

- **South Korea**: We process information under the Personal Information Protection Act. The privacy officer is listed below. Whether notices are required for cross-border transfers (Google, Apple, Cloudflare) needs professional confirmation.
- **EEA and UK (GDPR)**: Our legal bases are performance of a contract (purchase verification), legitimate interests (abuse prevention) and consent (your choice in the ad consent dialog). You have the rights of access, correction, deletion, portability, objection and withdrawal of consent, and you may complain to your supervisory authority.
- **United States (California and others)**: We do not sell personal information. Whether passing ad interaction data to third parties counts as "sharing" under state law depends on your ad settings [확인 필요].

## 11. Privacy officer and contact

- Person in charge: [name or title [확인 필요]]
- Email: [확인 필요]
- Address: [확인 필요] (if you are an individual developer, check how much of your address may be published)

## 12. Changes to this policy

If we change this policy, we will post the new effective date on the store page and in this document. For important changes (such as collecting more information) we will also tell you in the App or in the release notes [확인 필요].

---
*Draft written 2026-10-23. It summarizes facts confirmed from the code and is not legal advice.*
