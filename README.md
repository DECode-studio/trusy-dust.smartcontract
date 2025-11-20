# TrustyDust Smart Contracts

Dokumentasi lengkap konsumsi kontrak untuk frontend & backend, termasuk fungsi per kontrak, alur operasional, deployment, dan contoh implementasi.

## Arsitektur & Modul
- **Token & Identity**
  - `src/token/DustToken.sol` — ERC20 untuk trust score. Minter terbatas (TrustCore, RewardEngine, dll).
  - `src/identity/TrustBadgeSBT.sol` — ERC721 soulbound badge (Dust/Spark/Flare/Nova). Non-transferable.
  - `src/identity/TrustReputation1155.sol` — ERC1155 soulbound reputasi/achievement/akses. Non-transferable, modul authorized saja yang bisa mint/burn.
- **Core & Reward**
  - `src/core/TrustCoreImpl.sol` (upgradeable via `TrustCoreProxy`, admin `ProxyAdmin`) — logika inti reward sosial/job, tier helper.
  - `src/reward/RewardEngine.sol` — jalur reward terpisah (sosial, job, DAO) dengan `authorizedCaller`.
- **Jobs & Escrow**
  - `src/jobs/JobMarketplace.sol` — job board trust-gated (minScore via Dust balance).
  - `src/jobs/EscrowVault.sol` — escrow 80% ke worker, 20% ke `trustBonusRecipient`.
- **Verifikasi**
  - `src/verification/TrustVerification.sol` — hubungkan verifier Noir (trust score >= X, tier membership) dan update badge via TrustCore.

ABI tersedia setelah build di `out/`.

## Build & Test
```bash
forge build
forge test
```
Remapping telah diset di `foundry.toml`. Pastikan dependency di `lib/` terpasang (`forge install` bila perlu).

## Fungsi & Flow per Kontrak
### DustToken (ERC20)
- State: `isMinter[address]`.
- Fungsi: `setMinter(minter,bool)` (owner), `ownerMint`, `mint`, `burn`, `decimals()` 18.
- Flow: Owner set minter (TrustCore/RewardEngine). Minter memanggil `mint/burn` untuk ubah trust score (balance DUST).

### TrustBadgeSBT (ERC721 SBT)
- State: `tokenOf[user]`, `_badgeData[tokenId]{tier,metadataURI,lastUpdated}`.
- Fungsi: `mintBadge(user,tier,uri)`, `updateBadgeMetadata(user,newTier,newURI)` (owner only). Override `_update` blokir transfer user↔user.
- Flow: Core/RewardEngine (sebagai owner) mint/update badge sesuai hasil proof tier.

### TrustReputation1155 (ERC1155 SBT)
- State: `authorized[module]`.
- Fungsi: `setAuthorized(module,bool)` (owner), `mint/mintBatch`, `burn/burnBatch` (onlyAuthorized). Override `_update` blokir transfer biasa.
- Flow: Authorized modul (Core/RewardEngine/Job module) mint achievement/akses; tidak bisa ditransfer.

### TrustCoreImpl (Upgradeable)
- State penting: refs `dust`, `badge`, `reputation1155`, `rewardOperator`; config reward (like/comment/repost/jobBase); tier thresholds (Spark/Flare/Nova).
- Admin: `setRewardOperator`, `setRewardConfig`, `setDustTierThresholds`.
- Reward:
  - `rewardLike/Comment/Repost` → `_rewardSocial` mint DUST (scoreDelta * 1e18) + optional 1155.
  - `rewardJobCompletion(user, scoreDelta)` → mint DUST + JOB_COMPLETION_ACHIEVEMENT.
- View/helper: `getTrustScore` (balance DUST), `getTier`, `hasMinTrustScore`, `setUserBadgeTier` (mint/update SBT berdasarkan verifikasi eksternal).
- Flow: Backend (rewardOperator) panggil reward; trust score = saldo DUST; tier dihitung vs thresholds; badge sinkron via `setUserBadgeTier`.

### RewardEngine
- State: refs `dust`, `reputation1155`; `authorizedCaller`; reward config; quota harian like+repost (`maxSocialScorePerDay`, `dailySocial`).
- Admin: `setAuthorizedCaller`, `setRewardConfig`, set alamat dust/rep.
- Reward API:
  - `rewardLike/Repost` (share quota harian, default +1) → mint DUST + achievement ID 1001.
  - `rewardComment` (+3), `rewardJobCompletion(scoreDelta)`, `rewardRecommendation` (+100), `rewardDaoVoteWin` (+30) → DUST + 1155 ID terkait (1002/2001/2002/2003).
- Flow: Backend authorizedCaller memanggil; DUST minted via role minter; 1155 minted via authorized.

### JobMarketplace
- State: `jobs[jobId]{poster,token,rewardAmount,minScore,worker,status,createdAt}`, `nextJobId`; refs `escrow`, `trustCore`, `reputation1155`.
- Fungsi utama:
  - `createJob(token,rewardAmount,minScore)` → require trustCore/escrow set; lock dana via `escrow.fundJob`.
  - `applyToJob(jobId)` → check `trustCore.hasMinTrustScore`.
  - `assignWorker`, `submitWork`, `approveJob(jobId,rating)`, `rejectJob`, `cancelJob`.
  - `_computeScoreDelta(rating)` → 1⭐=20, 2⭐=50, 3⭐=100, 4⭐=150, 5⭐=200.
- Flow: Poster approve ERC20 → `createJob` → worker apply (event-based) → poster assign → worker submit → poster approve → Escrow release 80/20 + TrustCore.rewardJobCompletion(scoreDelta) + mint achievement 1155.

### EscrowVault
- State: `escrows[jobId]{token,poster,amount,funded,released,refunded}`, `marketplace`, `trustBonusRecipient`.
- Fungsi: `setMarketplace`, `setTrustBonusRecipient`; `fundJob` (only marketplace), `releaseToWorker` (80% ke worker, 20% ke bonus atau balik ke poster jika bonus unset), `refundPoster`.
- Flow: Dipanggil eksklusif JobMarketplace untuk lock/release/refund.

### TrustVerification
- State: `trustScoreVerifier`, `tierVerifier`, `trustCore`.
- Admin: setter untuk verifier & trustCore.
- Fungsi:
  - `verifyTrustScoreGeq(proof,minScore)` → build pubInputs (addr,minScore,1) → verifier → emit event.
  - `verifyTierAndUpdateBadge(proof,tier,metadataURI)` → pubInputs (addr,tier,1) → verifier → `trustCore.setUserBadgeTier`.
- Flow: Frontend kirim proof Noir; TrustVerification harus authorized (rewardOperator) di TrustCore agar dapat update badge.

### ProxyAdmin & TrustCoreProxy
- Proxy transparan OZ v5. `ProxyAdmin` wrapper: `upgradeAndCall`, `upgrade` (tanpa data). TrustCoreImpl dijalankan melalui proxy.

## Role & Konfigurasi
- DustToken owner: set minter modul (TrustCore/RewardEngine), optional bootstrap supply.
- Badge/Rep1155 owner: setAuthorized modul (TrustCore/RewardEngine/JobMarket); bisa serahkan ke multisig/core.
- TrustCore owner: set rewardOperator, reward config, tier thresholds.
- RewardEngine owner: set authorizedCaller, reward config, alamat dust/rep.
- JobMarketplace owner: set trustCore/escrow/reputation1155. Escrow owner: set marketplace dan trustBonusRecipient.
- TrustVerification owner: set verifier & trustCore; jadikan rewardOperator di TrustCore jika ingin update badge.

## Implementasi Backend (ethers.js v6 contoh)
### Reward via TrustCore (rewardOperator)
```ts
const provider = new ethers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(OPERATOR_KEY, provider);
const core = new ethers.Contract(TRUST_CORE_PROXY, TrustCoreAbi.abi, signer);

await core.rewardLike(user);
await core.rewardJobCompletion(user, 50); // scoreDelta 50
```
### Reward via RewardEngine (authorizedCaller)
```ts
const engine = new ethers.Contract(REWARD_ENGINE, EngineAbi.abi, signer);
await engine.rewardComment(user);         // +3
await engine.rewardRecommendation(user);  // +100
```
### Job + Escrow Flow
```ts
const job = new ethers.Contract(JOB_MARKET, JobAbi.abi, posterSigner);
const escrow = new ethers.Contract(ESCROW_VAULT, EscrowAbi.abi, posterSigner);
const erc20 = new ethers.Contract(ERC20_TOKEN, ERC20_ABI, posterSigner);

await erc20.approve(escrow.target, rewardAmount);
const { logs } = await (await job.createJob(ERC20_TOKEN, rewardAmount, minScore)).wait();
const jobId = Number(logs[0].args.jobId);

await job.connect(workerSigner).applyToJob(jobId);
await job.assignWorker(jobId, workerSigner.address);
await job.connect(workerSigner).submitWork(jobId);
await job.approveJob(jobId, 5); // release escrow + TrustCore reward
```
### Verifikasi ZK
```ts
const verify = new ethers.Contract(TRUST_VERIFY, VerifyAbi.abi, userSigner);
await verify.verifyTrustScoreGeq(proofBytes, 600);
await verify.verifyTierAndUpdateBadge(proofBytes, 2, "ipfs://tier2.json");
```

## Implementasi Frontend
- **Read**: `getTrustScore`, `getTier`, `DustToken.balanceOf`, `TrustBadgeSBT.getBadgeData`, `TrustReputation1155.balanceOf`, `jobs(jobId)`, event `JobCreated/Assigned/Submitted/Approved/Cancelled`.
- **Write**:
  - Worker: `applyToJob`, `submitWork`.
  - Poster: `createJob` (butuh allowance ERC20 ke escrow), `assignWorker`, `approveJob`, `rejectJob`, `cancelJob`.
  - Proof: `verifyTrustScoreGeq`, `verifyTierAndUpdateBadge`.
  - Badge metadata disiapkan backend; frontend kirim proof + metadata URI terpilih.

## Deployment (urutan rekomendasi)
1) Deploy `DustToken`.
2) Deploy `TrustBadgeSBT`, `TrustReputation1155`.
3) Deploy `TrustCoreImpl` (impl), `ProxyAdmin`, `TrustCoreProxy` (initialize owner, dust, badge, rep1155, rewardOperator).
4) Set role:
   - DustToken.setMinter(TrustCoreProxy, true) (+ RewardEngine jika perlu).
   - TrustReputation1155.setAuthorized(TrustCoreProxy, true).
   - Transfer ownership badge/rep1155 ke TrustCoreProxy atau multisig.
5) Deploy `RewardEngine` → setAuthorizedCaller backend → set sebagai minter/authorized.
6) Deploy `EscrowVault` (owner, trustBonusRecipient), `JobMarketplace` (owner, trustCore, escrow, rep1155) → `EscrowVault.setMarketplace(jobMarketplace)`.
7) Deploy `TrustVerification` → set verifier Noir + trustCore → jadikan rewardOperator bila perlu update badge.
8) Atur reward config/tier thresholds sesuai kebutuhan.

## Environment
```
RPC_URL=...
OPERATOR_KEY=...                  # rewardOperator / authorizedCaller
DUST_TOKEN=0x...
TRUST_CORE_PROXY=0x...
TRUST_BADGE=0x...
TRUST_REP1155=0x...
REWARD_ENGINE=0x...
JOB_MARKET=0x...
ESCROW_VAULT=0x...
TRUST_VERIFY=0x...
ERC20_REWARD_TOKEN=0x...          # token untuk job reward
```

## Tips Keamanan & Operasional
- Batasi minter/authorizedCaller/rewardOperator hanya pada modul/backends tepercaya.
- Pastikan `trustBonusRecipient` di Escrow benar; kalau kosong, bonus kembali ke poster.
- Selalu cek allowance ERC20 sebelum createJob.
- Upgrade TrustCore via `ProxyAdmin.upgradeAndCall`; perhatikan layout storage.
- Verifier ZK harus di-set sebelum proof publik diterima; pastikan sumber proof tepercaya.

## Flowchart (Teks)
### Social Reward (TrustCore & RewardEngine)
```
[Backend (authorized)] 
   └─call rewardLike/Comment/... 
       ├─(TrustCore/RewardEngine) onlyRewardOperator/onlyAuthorized checks
       ├─scoreDelta derived (config & quota)
       ├─mint DUST via DustToken.mint
       ├─mint Reputation1155 (if configured)
       └─emit event (SocialReward / ExtraReward / JobReward)
```

### Job + Escrow + Reward
```
[Poster]
   ├─approve ERC20 to EscrowVault
   └─createJob(token, reward, minScore) -> EscrowVault.fundJob (lock funds)
        └─Event JobCreated

[Worker]
   └─applyToJob -> TrustCore.hasMinTrustScore check -> Event JobApplied

[Poster]
   └─assignWorker -> Event JobAssigned

[Worker]
   └─submitWork -> status SUBMITTED -> Event JobSubmitted

[Poster]
   └─approveJob(rating)
        ├─EscrowVault.releaseToWorker (80% worker / 20% bonus)
        ├─TrustCore.rewardJobCompletion(scoreDelta from rating)
        ├─Reputation1155.mint achievement
        └─Event JobApproved
   (or rejectJob -> back to ASSIGNED; or cancelJob -> EscrowVault.refundPoster)
```

### ZK Verification + Badge Update
```
[User Frontend] -> obtain Noir proof off-chain
   └─submit verifyTrustScoreGeq(proof,minScore) or verifyTierAndUpdateBadge(proof,tier,URI)
        ├─TrustVerification builds pubInputs (addr, minScore/tier, qualified=1)
        ├─calls Noir verifier contract (trustScoreVerifier/tierVerifier)
        ├─if ok:
        │    └─for tier: trustCore.setUserBadgeTier(user, tier, URI)
        └─emit TrustScoreVerified / TierVerified
```

## Testing
Tes tersedia:
- `test/DustToken.t.sol` — minter rights, mint/burn.
- `test/RewardEngine.t.sol` — reward sosial/job/DAO, quota harian.
- `test/JobMarketplace.t.sol` — e2e job + escrow release + reward.
- `test/TrustVerification.t.sol` — proof trust score/tier dan update badge.

Jalankan:
```bash
forge test
```
