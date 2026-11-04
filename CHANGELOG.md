# Monopoly Banker Pro — Changelog

## v1.0.1 — 4 November 2026 (Stable Release)

This is a stable release, no longer a prerelease.

### New
- **Manual currency at game setup:** the new-game wizard now has a “Currency unit” field in the rules step. It starts at the chosen board’s own unit, but you can type any unit (e.g. “تومان”, “£”, “₺”) and every amount in that game is shown with it. Older saved games keep their board’s unit.
- **No-bid auctions:** the auction sheet now has a “No bids — property stays unowned” button. If nobody bids, nobody pays, the property stays unowned, the outcome is logged — and the turn is no longer blocked on that space, so play moves on. Landing on the same space again later still offers buy or auction.
- **Utility mortgage exception:** mortgaging a utility (Electric / Water company) always pays a flat **75**, and lifting its mortgage always costs **83**, regardless of the property’s printed price. Streets and railroads are unchanged (half price to mortgage, 55% to lift). The mortgage / lift amounts are now shown on the property buttons themselves.

### Compatibility
- Saves from earlier versions open unchanged; currency and auction state default automatically.
