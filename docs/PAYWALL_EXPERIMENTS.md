# Paywall experiments — owner's guide

How to change prices and A/B test the paywall. Written to be picked up cold.
(Built 2026-06-10; plan: `docs/superpowers/plans/2026-06-10-paywall-ab-testing.md`.)

## How the system works (30 seconds)

- The app asks the backend `GET /paywall` and shows **whatever packs the server
  says**, in that order, with a "MOST POPULAR" badge on the server-chosen card
  and an optional headline. If the call fails, it falls back to the baked-in
  four packs.
- Users are split into variants by a **hash of their account id** — stable,
  storage-free, the same user always sees the same variant for a given
  experiment key.
- The app reports only "paywall shown". The **server** computes which variant
  that user belongs to — at impression time AND at purchase time (inside
  `/credits/redeem`) — so results can't be skewed by a buggy or dishonest client.
- Events land in the D1 table `paywall_events`.

## One-time prerequisite (also blocks ALL revenue)

Create the four baseline consumable IAPs in **App Store Connect → Monetization
→ In-App Purchases**, with EXACTLY these product IDs (the code's IDs — not the
`Theory-of-Web.*` ones in the old monetisation spec):

| Product ID | Credits | Reference price |
|---|---|---|
| `com.ihsan.replr.credits.100`  | 100  | £1.99 |
| `com.ihsan.replr.credits.300`  | 300  | £4.99 |
| `com.ihsan.replr.credits.750`  | 750  | £9.99 |
| `com.ihsan.replr.credits.2500` | 2500 | £24.99 |

Each needs a display name, a one-line description, a price point, and a
review screenshot before Apple approves it.

## Changing a price WITHOUT an experiment

Just change the product's price in App Store Connect. The app reads prices
live from StoreKit (`product.displayPrice`) — no code, no deploy, no release.
Existing users see the new price on next paywall open.

## Launching an A/B test

Example: test whether 300 credits at £2.99 converts better than £4.99.

1. **App Store Connect:** create a NEW product
   `com.ihsan.replr.credits.300.p299` — 300 credits, £2.99. (A price test is
   always a separate product id; one product can't have two prices. The
   naming convention `.pNNN` = price in pence is just a convention — the app
   parses the credit count from the number right after `credits.`.)
2. **Backend, `src/services/models.ts`:** add it to `CREDIT_PACKS`
   (`'com.ihsan.replr.credits.300.p299': 300`) so redemption grants correctly.
3. **Backend, `src/services/paywall.ts`:** edit `ACTIVE_PAYWALL_EXPERIMENT`:

   ```ts
   export const ACTIVE_PAYWALL_EXPERIMENT: PaywallExperiment = {
     key: 'price-300-2026-07',          // NEW key = everyone re-bucketed
     variants: [
       { name: 'control', weight: 1,
         productIDs: [/* the four baseline ids */],
         badgeProductID: 'com.ihsan.replr.credits.300' },
       { name: 'p299', weight: 1,
         productIDs: ['com.ihsan.replr.credits.100',
                      'com.ihsan.replr.credits.300.p299',
                      'com.ihsan.replr.credits.750',
                      'com.ihsan.replr.credits.2500'],
         badgeProductID: 'com.ihsan.replr.credits.300.p299' },
     ],
   }
   ```

4. `cd backend && npm test && npm run deploy` — the test is live on next app
   foreground. **No App Store release.**

You can also test order, badge placement, and the headline (`heroCopy`)
without any ASC work at all.

## Reading results

```bash
npx wrangler d1 execute replr-db --remote --command \
  "SELECT experiment, variant, event, COUNT(DISTINCT user_id) AS users, COUNT(*) AS n
   FROM paywall_events GROUP BY 1, 2, 3"
```

Conversion per variant = `purchase` users ÷ `impression` users. Revenue per
variant: join `product_id` against pack prices by hand (counts are per product).

## Shipping the winner

Make the winning variant the only one (weight 1, delete the rest), keep the
same key or bump it — then deploy. Losers' ASC products can be removed from
sale afterwards.

## Rules that keep results honest

- **Don't reuse an experiment key** after changing variant definitions —
  bump it. The key is the bucketing salt; reusing it mixes populations.
- **Every product id served must exist in ASC and in `CREDIT_PACKS`** —
  otherwise the card won't render (StoreKit drops unknown ids) or redeem
  rejects the purchase.
- **TestFlight numbers are noise** — a few dozen testers can't reach
  significance. Use experiments on launch traffic; expect to need roughly
  1,000+ impressions per variant before conversion differences mean anything.
- **One experiment at a time** (the system holds one `ACTIVE_PAYWALL_EXPERIMENT`).
- Telemetry note: impressions/purchases are the app's only analytics —
  keyed to account id, no content. Mention purchase-flow analytics in the
  privacy policy at launch.
