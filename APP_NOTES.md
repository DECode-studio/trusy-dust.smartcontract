# TrustyDust Smart Contract Notes

## Gambaran Besar
- Ekosistem reputasi on-chain: `DustToken` (ERC20) merepresentasikan trust score, `TrustBadgeSBT` (ERC721 SBT) untuk tier, `TrustReputation1155` (ERC1155 SBT) untuk achievement/akses, dan modul reward/verification/jobs yang berinteraksi di atasnya.
- `TrustCoreImpl` adalah modul inti (upgradeable via `TrustCoreProxy` + `ProxyAdmin`) yang memegang konfigurasi reward dan menyediakan helper trust score/tier. Ia mint DUST + reputasi 1155 serta sinkronisasi badge.
- `RewardEngine` adalah jalur reward terpisah untuk sosial/DAO/job yang dikontrol via `authorizedCaller`; harus diset sebagai minter di DUST & authorized di 1155.
- `JobMarketplace` + `EscrowVault` menyediakan job board dengan syarat trust score; escrow membagi pembayaran 80% ke worker dan 20% ke `trustBonusRecipient`.
- `TrustVerification` menghubungkan verifier ZK (Noir) dengan update badge/tier via TrustCore.

## Modul & Alur Penting
- **Token (`src/token/DustToken.sol`)**: Implementasi ERC20 + `Ownable` dengan pencatat `isMinter`. Owner dapat set/revoke minter dan optional `ownerMint`. `mint/burn` hanya untuk minter; trust score diukur langsung dari balance DUST (18 desimal).
- **Identity**:
  - `TrustBadgeSBT`: ERC721 non-transferable; mapping `tokenOf` memastikan 1 badge per user. Owner (biasanya TrustCore/RewardEngine) bisa `mintBadge` atau `updateBadgeMetadata` dengan tier & URI baru; `tokenURI` membaca URI yang disimpan di `BadgeData`.
  - `TrustReputation1155`: ERC1155 non-transferable; `authorized` modul (TrustCore/RewardEngine/job module) dapat `mint/mintBatch/burn/burnBatch`; owner dapat update base URI dan daftar authorized.
  - `MetadataUtils`: helper sederhana untuk path metadata berdasarkan tier.
- **Core (`TrustCoreImpl`)**:
  - Upgradeable (Initializable + OwnableUpgradeable), menyimpan referensi `dust`, `badge`, `reputation1155`, serta `rewardOperator`.
  - Default reward konfigurasi: like=1, comment=3, repost=1, job base=50; tier thresholds: Spark=300e18, Flare=600e18, Nova=800e18.
  - `rewardLike/Comment/Repost` memanggil `_rewardSocial` → mint DUST (scoreDelta * 1e18) dan optional achievement 1155; `rewardJobCompletion` mint DUST + achievement 1155.
  - View helper `getTrustScore` (balance DUST), `getTier` (tier berdasarkan threshold), `hasMinTrustScore` (minScore dalam unit score, dikonversi ke wei). `setUserBadgeTier` memungkinkan rewardOperator memperbarui/mint badge SBT sesuai tier proof off-chain.
  - `ProxyAdmin` mengelola upgrade/admin proxy; `TrustCoreProxy` adalah transparent proxy wrapper.
- **Jobs**
  - `JobMarketplace`: Simpan data minimal job on-chain (poster, token reward, minScore, worker, status). `createJob` memaksa fund escrow; applicant tidak disimpan on-chain (hanya event). Trust gating via `trustCore.hasMinTrustScore` (minScore dalam unit score). Flow: OPEN → ASSIGNED (poster pilih) → SUBMITTED (worker submit) → COMPLETED (poster approve + beri rating) atau kembali ASSIGNED (reject). `approveJob` juga memicu `EscrowVault.releaseToWorker`, memanggil `trustCore.rewardJobCompletion` dengan delta berdasarkan rating (1→20, 2→50, 3→100, 4→150, 5→200) dan mint achievement 1155 jika diset.
  - `EscrowVault`: Hanya callable oleh marketplace. `fundJob` menyimpan token ERC20; `releaseToWorker` mengirim 80% ke worker dan 20% ke `trustBonusRecipient` (atau kembali ke poster jika recipient belum diset); `refundPoster` untuk pembatalan. Owner dapat ganti marketplace/recipient.
- **RewardEngine**:
  - Menangani reward sosial/pekerjaan/DAO terpisah dari TrustCore. `authorizedCaller` kontrol akses. Default reward: like=1, repost=1, comment=3, recommendation=100, daoVoteWin=30; limit harian like+repost tershared `maxSocialScorePerDay` (default 10). Daily quota dicatat per user (`DailySocialCounter`).
  - Semua reward memint DUST (scoreDelta * 1e18) dan mint reputasi 1155 dengan ID khusus (1001/1002/2001/2002/2003).
- **Verification (`TrustVerification`)**:
  - Menyimpan dua verifier Noir (`trustScoreVerifier`, `tierVerifier`) dan referensi `trustCore`. `verifyTrustScoreGeq` & `verifyTierAndUpdateBadge` membangun public inputs dari address + parameter, memanggil verifier, dan pada tier proof sukses memanggil `trustCore.setUserBadgeTier`.
  - Catatan: kode saat ini tidak kompilable (`bytes32;` tanpa deklarasi `pubInputs` array di kedua fungsi). Perlu diisi `bytes32[] memory pubInputs = new bytes32[](3);` agar verifier dapat dipanggil.

## Integrasi & Konfigurasi
- DUST harus menambahkan `TrustCoreImpl`/`RewardEngine` sebagai minter; `TrustReputation1155` butuh `setAuthorized` untuk modul-modul tersebut.
- Untuk alur upgrade, deploy `TrustCoreImpl` → deploy `ProxyAdmin` → deploy `TrustCoreProxy` dengan data `initialize` → gunakan ProxyAdmin untuk upgrade/charge admin.
- Job flow butuh ERC20 approval ke `EscrowVault` sebelum `createJob`; `EscrowVault.setMarketplace` harus diarahkan ke marketplace agar panggilan tidak fail.
- Verifikasi ZK bergantung pada kontrak verifier eksternal (Noir-generated); TrustVerification harus menjadi `rewardOperator` di TrustCore agar dapat update badge.

## Catatan Risiko / Pekerjaan Lanjutan
- Tidak ada test saat ini; perlu uji compilation dan flow end-to-end (minting, reward harian, escrow release, upgrade).
- `TrustVerification` perlu perbaikan deklarasi `pubInputs` agar build berhasil.
- `JobMarketplace` tidak menyimpan daftar pelamar; pemilihan worker sepenuhnya bergantung pada off-chain indexing event. Pastikan asumsi ini cocok dengan produk.

## Fungsi & Flow Utama
- Alur Social Reward (TrustCoreImpl): backend memanggil `rewardLike/Comment/Repost` → cek onlyRewardOperator → hitung `scoreDelta` → `dust.mint(user, scoreDelta * 1e18)` → optional mint achievement 1155 → emit event. Trust score = saldo DUST.
- Alur Job Reward (TrustCoreImpl): backend/job module memanggil `rewardJobCompletion(user, scoreDelta)` → mint DUST + reputasi 1155 → event. Tier dihitung dari saldo DUST versus threshold (Spark/Flare/Nova).
- Alur RewardEngine: authorized caller (backend) memanggil `rewardLike/Repost/Comment/Recommendation/DaoVoteWin/JobCompletion` → daily quota check untuk like+repost → mint DUST + 1155 ID terkait. Wajib diset sebagai minter DUST & authorized 1155.
- Alur Badge Tier: modul ter-authorized memanggil `setUserBadgeTier` pada TrustCoreImpl → jika user belum punya badge maka mint, kalau sudah update metadata (tier + URI) di SBT non-transferable.
- Alur Job Marketplace: poster approve token ke `EscrowVault` → `createJob` lock reward + emit event → worker apply (trustScore check melalui TrustCore) → poster `assignWorker` → worker `submitWork` → poster `approveJob(rating)` memicu escrow release 80/20 + `trustCore.rewardJobCompletion` (scoreDelta dari rating) + mint achievement 1155; jika perlu `rejectJob` atau `cancelJob` memanggil refund escrow.
- Alur EscrowVault: hanya dipanggil JobMarketplace. `fundJob` transferFrom poster → vault; `releaseToWorker` kirim 80% ke worker + 20% ke `trustBonusRecipient`; fallback bonus ke poster jika recipient kosong; `refundPoster` saat cancel sebelum release.
- Alur Verifikasi ZK: TrustVerification menyimpan alamat verifier Noir. `verifyTrustScoreGeq` dan `verifyTierAndUpdateBadge` membangun `pubInputs` (addr, minScore/tier, qualified) → panggil `trustScoreVerifier`/`tierVerifier`. Setelah tier proof valid, panggil `trustCore.setUserBadgeTier` untuk sinkronisasi badge.
