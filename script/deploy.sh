#!/bin/bash
set -e

source .env

echo "===================================="
echo " Deploying TrustyDust on Base Sepolia"
echo "===================================="

# 1. Clean & Build
forge clean
forge build

echo ""
echo "✅ BUILD SUCCESS"
echo ""

# 2. DEPLOY ALL CONTRACTS
echo "🚀 Starting deployment..."

forge script script/Deploy.s.sol:Deploy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --chain-id 84532 \
  --broadcast \
  -vvvv

echo ""
echo "✅ DEPLOY DONE"
echo ""

sleep 90

echo "===================================="
echo " Starting manual verification step"
echo "===================================="

# 3. GET DEPLOYER ADDRESS
DEPLOYER=$(cast wallet address $PRIVATE_KEY)
echo "Deployer: $DEPLOYER"

# 4. REPLACE THESE WITH REAL ADDRESSES FROM LOG
DUST="0x5B99B1363F634CbF43FC13bd6D425285022aC469"
IDENTITY="0x8219dF54d4de0012Fde4BaBf0D39437f4652B85d"
CORE="0xA6b64d740De8FFD7EFD67Ff6296cD3CC9A0aac04"
CONTENT="0x9C41c06011d228f08B907B073D3a12800d35C0e9"
JOBS="0x0691D75F7689142c304CE49ae89eaDC13Ab2cF27"
VERIFIER="0xC206a244Ff6f8104d24f78994a8b47D72D0c1d0D"

echo ""
echo "⚠️  Update contract address manually first!"
echo ""

# =============================
# VERIFY DUST TOKEN
# =============================

echo "✅ VERIFYING DustToken"

forge verify-contract \
  --chain-id 84532 \
  $DUST \
  src/DustToken.sol:DustToken \
  --constructor-args $(cast abi-encode "constructor(string,string,address)" "Dust" "DUST" $DEPLOYER) \
  --num-of-optimizations 200 \
  --compiler-version 0.8.30 \
  --watch

# =============================
# VERIFY IDENTITY
# =============================

echo "✅ VERIFYING Identity"

forge verify-contract \
  --chain-id 84532 \
  $IDENTITY \
  src/Identity.sol:Identity \
  --num-of-optimizations 200 \
  --compiler-version 0.8.30 \
  --watch

# =============================
# VERIFY CORE
# =============================

echo "✅ VERIFYING Core"

forge verify-contract \
  --chain-id 84532 \
  $CORE \
  src/Core.sol:Core \
  --constructor-args $(cast abi-encode "constructor(address,address)" $IDENTITY $DUST) \
  --num-of-optimizations 200 \
  --compiler-version 0.8.30 \
  --watch

# =============================
# VERIFY CONTENT
# =============================

echo "✅ VERIFYING Content"

forge verify-contract \
  --chain-id 84532 \
  $CONTENT \
  src/Content.sol:Content \
  --constructor-args $(cast abi-encode "constructor(address,address)" $IDENTITY $DUST) \
  --num-of-optimizations 200 \
  --compiler-version 0.8.30 \
  --watch

# =============================
# VERIFY JOBS
# =============================

echo "✅ VERIFYING Jobs"

forge verify-contract \
  --chain-id 84532 \
  $JOBS \
  src/Jobs.sol:Jobs \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" $IDENTITY $DUST $CORE) \
  --num-of-optimizations 200 \
  --compiler-version 0.8.30 \
  --watch

# =============================
# VERIFY VERIFIER
# =============================

echo "✅ VERIFYING Verifier"

forge verify-contract \
  --chain-id 84532 \
  $VERIFIER \
  src/Verifier.sol:Verifier \
  --constructor-args $(cast abi-encode "constructor(address)" $IDENTITY) \
  --num-of-optimizations 200 \
  --compiler-version 0.8.30 \
  --watch

echo ""
echo "✅✅✅ ALL CONTRACTS VERIFIED SUCCESSFULLY ✅✅✅"
