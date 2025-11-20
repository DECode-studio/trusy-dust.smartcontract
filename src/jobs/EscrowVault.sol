// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title EscrowVault
/// @notice Vault escrow untuk pembayaran job di TrustyDust.
///         Hanya JobMarketplace yang boleh fund/release/refund.
contract EscrowVault is Ownable {
    struct Escrow {
        address token; // ERC20 token address (USDC / LISK-ERC20 / dst)
        address poster; // yang deposit
        uint256 amount; // total dana di escrow
        bool funded;
        bool released;
        bool refunded;
    }

    /// @dev jobId => escrow data
    mapping(uint256 => Escrow) public escrows;

    /// @dev alamat JobMarketplace
    address public marketplace;

    /// @dev penerima 20% "trust bonus" (bisa DAO treasury / RewardEngine)
    address public trustBonusRecipient;

    event MarketplaceUpdated(
        address indexed oldMarketplace,
        address indexed newMarketplace
    );
    event TrustBonusRecipientUpdated(
        address indexed oldRecipient,
        address indexed newRecipient
    );
    event JobFunded(
        uint256 indexed jobId,
        address indexed poster,
        address indexed token,
        uint256 amount
    );
    event JobReleased(
        uint256 indexed jobId,
        address indexed worker,
        uint256 workerAmount,
        uint256 bonusAmount
    );
    event JobRefunded(
        uint256 indexed jobId,
        address indexed poster,
        uint256 amount
    );

    modifier onlyMarketplace() {
        require(msg.sender == marketplace, "Escrow: not marketplace");
        _;
    }

    constructor(address owner_, address trustBonusRecipient_)
        Ownable(owner_)
    {
        require(owner_ != address(0), "Escrow: zero owner");
        trustBonusRecipient = trustBonusRecipient_;
    }

    function setMarketplace(address m) external onlyOwner {
        require(m != address(0), "Escrow: zero marketplace");
        emit MarketplaceUpdated(marketplace, m);
        marketplace = m;
    }

    function setTrustBonusRecipient(address r) external onlyOwner {
        require(r != address(0), "Escrow: zero recipient");
        emit TrustBonusRecipientUpdated(trustBonusRecipient, r);
        trustBonusRecipient = r;
    }

    /// @notice Dipanggil JobMarketplace saat createJob.
    /// @dev poster harus sudah approve EscrowVault untuk amount tersebut.
    function fundJob(
        uint256 jobId,
        address token,
        address poster,
        uint256 amount
    ) external onlyMarketplace {
        require(!escrows[jobId].funded, "Escrow: already funded");
        require(token != address(0), "Escrow: zero token");
        require(poster != address(0), "Escrow: zero poster");
        require(amount > 0, "Escrow: zero amount");

        escrows[jobId] = Escrow({
            token: token,
            poster: poster,
            amount: amount,
            funded: true,
            released: false,
            refunded: false
        });

        // transfer token dari poster ke vault
        IERC20(token).transferFrom(poster, address(this), amount);

        emit JobFunded(jobId, poster, token, amount);
    }

    /// @notice Release dana ke worker (80%) + trustBonusRecipient (20%).
    function releaseToWorker(
        uint256 jobId,
        address worker
    ) external onlyMarketplace {
        Escrow storage e = escrows[jobId];
        require(e.funded, "Escrow: not funded");
        require(!e.released, "Escrow: already released");
        require(!e.refunded, "Escrow: refunded");
        require(worker != address(0), "Escrow: zero worker");

        e.released = true;

        uint256 total = e.amount;
        uint256 workerAmount = (total * 80) / 100;
        uint256 bonusAmount = total - workerAmount; // 20%

        IERC20(e.token).transfer(worker, workerAmount);
        if (trustBonusRecipient != address(0) && bonusAmount > 0) {
            IERC20(e.token).transfer(trustBonusRecipient, bonusAmount);
        } else if (bonusAmount > 0) {
            // fallback: kalau trustBonusRecipient belum di-set, kembalikan ke poster
            IERC20(e.token).transfer(e.poster, bonusAmount);
        }

        emit JobReleased(jobId, worker, workerAmount, bonusAmount);
    }

    /// @notice Refund dana ke poster (kalau job dicancel sebelum selesai).
    function refundPoster(uint256 jobId) external onlyMarketplace {
        Escrow storage e = escrows[jobId];
        require(e.funded, "Escrow: not funded");
        require(!e.released, "Escrow: already released");
        require(!e.refunded, "Escrow: already refunded");

        e.refunded = true;

        IERC20(e.token).transfer(e.poster, e.amount);

        emit JobRefunded(jobId, e.poster, e.amount);
    }
}
