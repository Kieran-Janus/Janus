---
description: Add a promo code. Usage: /new-code <CODE> <reward> [expiry date]
---

Add a promo code: $ARGUMENTS

1. Add it to `Config.Codes.List` (Code in capitals, Coins and/or Item Id, Expires as "YYYY-MM-DD" or "" for never). Item must be an Id from `Config.Shop.Items`.
2. Check the code doesn't already exist. Don't remove old codes; expire them instead.
3. Playtest: redeem it with the Codes button, then try again (should say already used).
4. Commit "Add code <CODE>" and push. Give me a one-line announcement I can post with it.
