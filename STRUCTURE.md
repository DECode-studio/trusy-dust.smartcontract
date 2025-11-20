contracts/
│
├── core/
│   ├── TrustCoreProxy.sol
│   ├── TrustCoreImpl.sol
│   └── ProxyAdmin.sol
│
├── identity/
│   ├── TrustBadgeSBT.sol
│   ├── TrustReputation1155.sol
│   └── MetadataUtils.sol         # helper update metadata
│
├── verification/
│   └── TrustVerification.sol     # ZK verifier
│
├── token/
│   ├── DustToken.sol
│   └── TokenErrors.sol
│
├── jobs/
│   ├── JobMarketplace.sol
│   ├── EscrowVault.sol
│   └── JobEvents.sol             # shared event definitions
│
├── reward/
│   └── RewardEngine.sol
│
├── interfaces/
│   ├── ITrustCore.sol
│   ├── IJobMarketplace.sol
│   ├── IDustToken.sol
│   ├── IReputation1155.sol
│   ├── IBadgeSBT.sol
│   └── ITrustVerification.sol
│
└── libs/
    ├── SafeTransferLib.sol
    ├── MathUtils.sol
    └── Errors.sol
