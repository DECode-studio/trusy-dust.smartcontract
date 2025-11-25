# TrustyDust Smart Contract Notes

## Gambaran Besar
- Ekosistem reputasi on-chain: `DustToken` (ERC20) merepresentasikan trust score, `TrustBadgeSBT` (ERC721 SBT) untuk tier, `TrustReputation1155` (ERC1155 SBT) untuk achievement/akses, modul reward/verification/jobs, dan `PostContentNFT` untuk konten yang burn DUST.
- `TrustCoreImpl` adalah modul inti (upgradeable via `TrustCoreProxy` + `ProxyAdmin`) yang memegang konfigurasi reward dan menyediakan helper trust score/tier. Ia mint DUST + reputasi 1155 serta sinkronisasi badge.
- `RewardEngine` adalah jalur reward terpisah untuk sosial/DAO/job yang dikontrol via `authorizedCaller`; harus diset sebagai minter di DUST & authorized di 1155.
- `JobMarketplace` (tanpa escrow): poster burn 10 DUST saat create job; tidak ada gaji on-chain, hanya reward reputasi via TrustCore.
- `TrustVerification` menghubungkan verifier ZK (Noir) dengan update badge/tier via TrustCore.
- `PostContentNFT`: ERC721 untuk post; mint membakar 10 DUST dan optional mint 1155 badge.

## Modul & Alur Penting
- **Token (`src/token/DustToken.sol`)**: Implementasi ERC20 + `Ownable` dengan pencatat `isMinter`. Owner dapat set/revoke minter dan optional `ownerMint`. `mint/burn` hanya untuk minter; trust score diukur langsung dari balance DUST (18 desimal).
- **Identity**:
  - `TrustBadgeSBT`: ERC721 non-transferable; mapping `tokenOf` memastikan 1 badge per user. Owner (biasanya TrustCore/RewardEngine) bisa `mintBadge` atau `updateBadgeMetadata` dengan tier & URI baru; `tokenURI` membaca URI yang disimpan di `BadgeData`.
  - `TrustReputation1155`: ERC1155 non-transferable; `authorized` modul (TrustCore/RewardEngine/job module/PostContentNFT) dapat `mint/mintBatch/burn/burnBatch`; owner dapat update base URI dan daftar authorized.
  - `MetadataUtils`: helper sederhana untuk path metadata berdasarkan tier.
  - `PostContentNFT`: ERC721 konten/post; `mintPost(uri)` membakar 10 DUST dan optional mint 1155 badge (postBadgeId) jika diset. Kontrak harus jadi minter DUST dan authorized di Rep1155.
- **Core (`TrustCoreImpl`)**:
  - Upgradeable (Initializable + OwnableUpgradeable), menyimpan referensi `dust`, `badge`, `reputation1155`, serta `rewardOperator`.
  - Default reward konfigurasi: like=1, comment=3, repost=1, job base=50; tier thresholds: Spark=300e18, Flare=600e18, Nova=800e18.
  - `rewardLike/Comment/Repost` memanggil `_rewardSocial` → mint DUST (scoreDelta * 1e18) dan optional achievement 1155; `rewardJobCompletion` mint DUST + achievement 1155.
  - View helper `getTrustScore` (balance DUST), `getTier` (tier berdasarkan threshold), `hasMinTrustScore` (minScore dalam unit score, dikonversi ke wei). `setUserBadgeTier` memungkinkan rewardOperator memperbarui/mint badge SBT sesuai tier proof off-chain.
  - `ProxyAdmin` mengelola upgrade/admin proxy; `TrustCoreProxy` adalah transparent proxy wrapper.
- **Jobs**
  - `JobMarketplace`: Simpan data minimal job on-chain (poster, minScore, worker, status). `createJob` membakar 10 DUST (kontrak harus jadi minter) sebagai fee; tidak ada escrow/gaji. Trust gating via `trustCore.hasMinTrustScore` (minScore dalam unit score). Flow: OPEN → ASSIGNED (poster pilih) → SUBMITTED → COMPLETED (poster approve + rating) atau kembali ASSIGNED (reject) atau CANCELLED. `approveJob` memanggil `trustCore.rewardJobCompletion` (scoreDelta rating 20/50/100/150/200) + mint achievement 1155 jika diset.
- **RewardEngine**:
  - Menangani reward sosial/pekerjaan/DAO terpisah dari TrustCore. `authorizedCaller` kontrol akses. Default reward: like=1, repost=1, comment=3, recommendation=100, daoVoteWin=30; limit harian like+repost tershared `maxSocialScorePerDay` (default 10). Daily quota dicatat per user (`DailySocialCounter`).
  - Semua reward memint DUST (scoreDelta * 1e18) dan mint reputasi 1155 dengan ID khusus (1001/1002/2001/2002/2003).
- **Verification (`TrustVerification`)**:
  - Menyimpan dua verifier Noir (`trustScoreVerifier`, `tierVerifier`) dan referensi `trustCore`. `verifyTrustScoreGeq` & `verifyTierAndUpdateBadge` membangun public inputs dari address + parameter, memanggil verifier, dan pada tier proof sukses memanggil `trustCore.setUserBadgeTier`.

## Integrasi & Konfigurasi
- DUST harus menambahkan `TrustCoreImpl`/`RewardEngine` sebagai minter; `TrustReputation1155` butuh `setAuthorized` untuk modul-modul tersebut.
- Untuk alur upgrade, deploy `TrustCoreImpl` → deploy `ProxyAdmin` → deploy `TrustCoreProxy` dengan data `initialize` → gunakan ProxyAdmin untuk upgrade/charge admin.
- Job flow: tidak ada escrow; poster harus memiliki ≥10 DUST dan JobMarketplace harus jadi minter DUST untuk membakar fee saat `createJob`.
- Verifikasi ZK bergantung pada kontrak verifier eksternal (Noir-generated); TrustVerification harus menjadi `rewardOperator` di TrustCore agar dapat update badge.
- PostContent: PostContentNFT butuh peran minter di DUST dan authorized di Rep1155 (bila postBadgeId digunakan).

## Catatan Risiko / Pekerjaan Lanjutan
- Tes sekarang tersedia dan lulus (36/36) untuk DustToken, RewardEngine, JobMarketplace (fee burn), PostContentNFT, TrustVerification, dan integrasi/deployment. Perluasan coverage lebih lanjut masih bisa dilakukan untuk modul lain.
- JobMarketplace tidak menyimpan daftar pelamar; pemilihan worker sepenuhnya bergantung pada off-chain indexing event. Pastikan asumsi ini cocok dengan produk.
- Pastikan role minter/authorized disetel tepat untuk JobMarketplace dan PostContentNFT agar burn/mint tidak gagal.

## Fungsi & Flow Utama
- Alur Social Reward (TrustCoreImpl): backend memanggil `rewardLike/Comment/Repost` → cek onlyRewardOperator → hitung `scoreDelta` → `dust.mint(user, scoreDelta * 1e18)` → optional mint achievement 1155 → emit event. Trust score = saldo DUST.
- Alur Job Reward (TrustCoreImpl): backend/job module memanggil `rewardJobCompletion(user, scoreDelta)` → mint DUST + reputasi 1155 → event. Tier dihitung dari saldo DUST versus threshold (Spark/Flare/Nova).
- Alur RewardEngine: authorized caller (backend) memanggil `rewardLike/Repost/Comment/Recommendation/DaoVoteWin/JobCompletion` → daily quota check untuk like+repost → mint DUST + 1155 ID terkait. Wajib diset sebagai minter DUST & authorized 1155.
- Alur Badge Tier: modul ter-authorized memanggil `setUserBadgeTier` pada TrustCoreImpl → jika user belum punya badge maka mint, kalau sudah update metadata (tier + URI) di SBT non-transferable.
- Alur Job Marketplace: poster burn 10 DUST pada `createJob(minScore)` → worker apply (trustScore check melalui TrustCore) → poster assign → worker submit → poster approve (reward reputasi via TrustCore + 1155 achievement). Tidak ada escrow/gaji on-chain.
- Alur PostContentNFT: user `mintPost(uri)` → kontrak burn 10 DUST dari caller → mint ERC721 post → optional mint 1155 badge jika `postBadgeId` diset.
- Alur Verifikasi ZK: TrustVerification menyimpan alamat verifier Noir. `verifyTrustScoreGeq` dan `verifyTierAndUpdateBadge` membangun `pubInputs` (addr, minScore/tier, qualified) → panggil verifier. Setelah tier proof valid, panggil `trustCore.setUserBadgeTier` untuk sinkronisasi badge.
