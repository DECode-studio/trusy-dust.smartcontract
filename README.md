# TrustyDust Smart Contracts

Panduan singkat untuk mengonsumsi kontrak (frontend & backend), build, testing, dan integrasi.

## Arsitektur Ringkas
- Token & Identity
  - `src/token/DustToken.sol` — ERC20 trust score (mint/burn oleh modul authorized).
  - `src/identity/TrustBadgeSBT.sol` — ERC721 soulbound badge (tier Dust/Spark/Flare/Nova).
  - `src/identity/TrustReputation1155.sol` — ERC1155 soulbound untuk achievement/akses.
- Core & Reward
  - `src/core/TrustCoreImpl.sol` (+ proxy `TrustCoreProxy`, admin `ProxyAdmin`): logika utama trust score, reward sosial, tier helper.
  - `src/reward/RewardEngine.sol`: jalur reward terpisah untuk sosial/DAO/job, dikontrol `authorizedCaller`.
- Jobs & Escrow
  - `src/jobs/JobMarketplace.sol`: job board trust-gated.
  - `src/jobs/EscrowVault.sol`: escrow 80% ke worker, 20% ke `trustBonusRecipient`.
- Verifikasi
  - `src/verification/TrustVerification.sol`: menghubungkan verifier Noir untuk proof trust score/tier ke TrustCore.

Semua ABI tersedia setelah build di `out/`.

## Build & Test
```bash
forge build
forge test
```
Jika butuh remapping, sudah diset di `foundry.toml`. Pastikan `lib/` terinstall (forge akan install otomatis via `forge install`).

## Peran & Konfigurasi Kontrak
- DustToken
  - Owner: set/revoke `isMinter`, optional `ownerMint`.
  - Minter: modul seperti TrustCoreImpl / RewardEngine.
- TrustBadgeSBT & TrustReputation1155
  - Owner: setAuthorized (1155), mint/update badge (721).
  - Non-transferable: hanya mint/burn yang diizinkan.
- TrustCoreImpl (upgradeable)
  - Owner: set reward config, dust tier thresholds, rewardOperator.
  - rewardOperator: memanggil reward sosial/job & sinkronisasi badge tier.
- RewardEngine
  - Owner: setAuthorizedCaller, reward config, alamat dust/rep1155.
  - authorizedCaller: backend/social indexer/job module yang memanggil fungsi reward.
- JobMarketplace/EscrowVault
  - Owner: setTrustCore, setEscrowVault, setReputation1155, setMarketplace/trustBonusRecipient (Escrow).
  - Poster: approve token → createJob → assign/approve/reject/cancel.
- TrustVerification
  - Owner: set verifier address (Noir), set trustCore.
  - Memanggil TrustCore untuk update badge setelah proof tier.

## Alur Konsumsi (Backend)
Contoh pseudocode dengan ethers.js (v6):
```ts
import { ethers } from "ethers";
import DustTokenAbi from "./out/DustToken.sol/DustToken.json";
import TrustCoreAbi from "./out/TrustCoreImpl.sol/TrustCoreImpl.json";

const provider = new ethers.JsonRpcProvider(RPC_URL);
const signer = new ethers.Wallet(PRIVATE_KEY, provider);

// Mint reward sosial via TrustCore (rewardOperator)
const trustCore = new ethers.Contract(TRUST_CORE_PROXY, TrustCoreAbi.abi, signer);
await trustCore.rewardLike(userAddress);

// Set minter di DustToken (owner call)
const dust = new ethers.Contract(DUST_TOKEN, DustTokenAbi.abi, signer);
await dust.setMinter(TRUST_CORE_PROXY, true);
```
Alur Job:
```ts
import JobMarketAbi from "./out/JobMarketplace.sol/JobMarketplace.json";
import EscrowAbi from "./out/EscrowVault.sol/EscrowVault.json";

const job = new ethers.Contract(JOB_MARKET, JobMarketAbi.abi, signer);
const escrow = new ethers.Contract(ESCROW_VAULT, EscrowAbi.abi, signer);

// Poster approve ERC20 ke escrow
const erc20 = new ethers.Contract(ERC20_TOKEN, ERC20_ABI, signer);
await erc20.approve(escrow.target, rewardAmount);

// Create job
const tx = await job.createJob(ERC20_TOKEN, rewardAmount, minScore);
const receipt = await tx.wait();
const jobId = receipt.logs[0].args.jobId;

// Assign worker, submit, approve
await job.assignWorker(jobId, worker);
// worker submits off-chain trigger
await job.submitWork(jobId);
await job.approveJob(jobId, rating); // triggers escrow release + TrustCore reward
```

## Alur Konsumsi (Frontend)
- Baca status:
  - Trust score: `TrustCoreImpl.getTrustScore(user)` atau langsung `DustToken.balanceOf(user)`.
  - Tier: `TrustCoreImpl.getTier(user)` → 0/1/2/3; metadata badge via `TrustBadgeSBT.getBadgeData(user)`.
  - Job listing (on-chain minimal): pakai event `JobCreated` untuk daftar; `jobs(jobId)` untuk detail status.
- Tulis (perhatikan roles):
  - Pengguna umum: call `applyToJob`, `submitWork`.
  - Poster: call `createJob`, `assignWorker`, `approveJob`, `rejectJob`, `cancelJob`.
  - Badge view: `tokenURI(tokenId)` mengembalikan metadata URI tersimpan.
Gunakan provider + signer sesuai peran; untuk read-only cukup provider publik.

## Integrasi ZK (TrustVerification)
- Set verifier Noir address via owner.
- Frontend kirim proof + parameter:
  - `verifyTrustScoreGeq(proof, minScore)` → emit event jika valid.
  - `verifyTierAndUpdateBadge(proof, tier, metadataURI)` → update badge via TrustCore (TrustVerification harus jadi rewardOperator di TrustCore).

## Deployment (contoh urutan)
1) Deploy `DustToken` (owner = multisig/deployer).
2) Deploy `TrustBadgeSBT`, `TrustReputation1155` (owner sementara deployer).
3) Deploy `TrustCoreImpl` implementation, `ProxyAdmin`, lalu `TrustCoreProxy` dengan data `initialize(owner, dust, badge, rep1155, rewardOperator)`.
4) Set role:
   - DustToken.setMinter(trustCoreProxy, true)
   - TrustReputation1155.setAuthorized(trustCoreProxy, true)
   - Transfer ownership badge/reputation ke TrustCoreProxy jika mau centralize.
5) Deploy `RewardEngine` dan beri minter/authorized sesuai kebutuhan.
6) Deploy `EscrowVault` (owner, trustBonusRecipient), `JobMarketplace` (owner, trustCore, escrow, rep1155), lalu set `EscrowVault.setMarketplace(jobMarketplace)`.
7) Deploy `TrustVerification` dan set verifier + trustCore, jadikan rewardOperator jika perlu update badge.

## Address & Env
Sediakan alamat RPC, key, dan alamat kontrak di env aplikasi:
```
RPC_URL=...
DUST_TOKEN=0x...
TRUST_CORE_PROXY=0x...
TRUST_BADGE=0x...
TRUST_REP1155=0x...
REWARD_ENGINE=0x...
JOB_MARKET=0x...
ESCROW_VAULT=0x...
TRUST_VERIFY=0x...
```

## Tips Keamanan & Operasional
- Set minter/authorized hanya untuk modul yang diperlukan; cabut bila tidak dipakai.
- Batasi rewardOperator/authorizedCaller ke backend yang dikontrol.
- Periksa allowance ERC20 sebelum createJob; pastikan escrow & trustBonusRecipient benar.
- Upgrade: gunakan `ProxyAdmin` untuk upgrade TrustCoreImpl via `upgradeAndCall`.

## Testing Lokal
Gunakan test yang sudah ada sebagai referensi:
- `test/DustToken.t.sol` — hak minter, mint/burn.
- `test/RewardEngine.t.sol` — reward sosial/job/DAO, quota harian.
- `test/JobMarketplace.t.sol` — end-to-end job + escrow release.
- `test/TrustVerification.t.sol` — proof trust score/tier dan update badge.

Jalankan:
```bash
forge test
```
