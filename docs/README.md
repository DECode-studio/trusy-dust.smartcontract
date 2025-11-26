Simple overview for backend engineers:

- DUST = points token (ERC20). No built-in roles; any caller can mint/burn in this skeleton (wire as needed).
- Identity = user table (trustScore, tier, reputation, posts, jobsCompleted, hasBadge).
- Core = reward engine. `rewardSocial(user, action)` and `rewardJob(user, rating)` add trustScore and mint DUST (all in DUST units, 18 decimals).
- Content = post flow: `mintPost` burns 10 DUST from caller, increments posts.
- Jobs = job board: `createJob` burns 10 DUST; `approveJob` triggers Core.rewardJob; statuses: OPEN, COMPLETED, CANCELLED.
- Verifier = optional wrapper to external verifier to update tier in Identity.

TrustScore = user reputation points.
Tier = level derived from trust score (set by verifier or external logic).

Project structure:
- contracts/: Core, Identity, Content, Jobs, DustToken, Verifier, SharedTypes, Errors.
- docs/: README, ARCHITECTURE, CONTRACT_MAP.
- test/: Base + per-contract tests (Core.t.sol, Identity.t.sol, Content.t.sol, Jobs.t.sol, DustToken.t.sol, Verifier.t.sol).

Deployment (sequential):
1) Deploy DustToken.
2) Deploy Identity.
3) Deploy Core (pass Identity, DustToken).
4) Deploy Content (pass Identity, DustToken).
5) Deploy Jobs (pass Identity, DustToken, Core).
6) Deploy Verifier (pass Identity), then setVerifiers if needed.

Testing:
```bash
forge test
```
Tests cover happy paths, reverts, and basic fuzz for transfers/rewards.
