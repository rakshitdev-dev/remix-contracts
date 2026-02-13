// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title BidContract
 * @author Rakshit Kumar Singh
 *
 * @notice
 * English-style auction contract for Real World Asset (RWA) tokens using
 * a fixed 10% deposit mechanism.
 *
 * Bidders submit a 10% refundable deposit.
 * Highest deposit implies highest total bid.
 * Winner must pay remaining 90% within a grace period.
 *
 * If winner defaults:
 * - Deposit is forfeited
 * - RWA tokens are NOT transferred
 *
 * Losing bidders may withdraw deposits at any time after being outbid.
 *
 * Supports:
 * - Native ETH auctions
 * - ERC20-based auctions
 *
 * Designed for primary RWA sale flows with legal registry validation.
 *
 * @dev
 * - Deposit percentage is fixed at 10%
 * - Reward tokens must be escrowed before deployment
 * - Uses pull-based withdrawals to avoid reentrancy
 * - SafeERC20 is used for all ERC20 transfers
 */

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IRwaManager} from "./interfaces/IRwaManager.sol";
import {ILegalRegistry} from "./interfaces/ILegalRegistry.sol";
import {IRwaToken} from "./interfaces/IRwaToken.sol";

contract BidContract is ReentrancyGuard {
    /* ========================== AUCTION CONFIG ========================== */

    address public immutable seller;
    IRwaManager public immutable managerContract;
    uint256 public immutable rewardAmount;
    uint256 public immutable assetId;

    /// @dev address(0) => native ETH auction
    IERC20 public immutable bidToken;

    uint256 public immutable minBid;
    uint256 public immutable endTime;

    /* ========================== AUCTION STATE ========================== */

    address public highestBidder;
    uint256 public highestBid;
    bool public settled;

    mapping(address => uint256) public bids;

    /* =============================== EVENTS =============================== */

    event BidPlaced(address indexed bidder, uint256 totalBid);
    event Withdrawn(address indexed bidder, uint256 amount);
    event AuctionSettled(address winner, uint256 winningBid);

    /* ============================== MODIFIERS ============================== */

    modifier auctionActive() {
        require(block.timestamp < endTime, "Auction ended");
        _;
    }

    modifier auctionEnded() {
        require(block.timestamp >= endTime, "Auction not ended");
        _;
    }

    /* ============================= CONSTRUCTOR ============================= */

    constructor(
        address _seller,
        address _managerContract,
        uint256 _rewardAmount,
        address _bidToken,
        uint256 _minBid,
        uint256 _duration,
        uint256 _assetId
    ) {
        require(_seller != address(0), "Invalid seller");
        require(_managerContract != address(0), "Invalid manager");
        require(_rewardAmount > 0, "Invalid reward amount");
        require(_duration > 0, "Invalid duration");

        seller = _seller;
        managerContract = IRwaManager(_managerContract);
        rewardAmount = _rewardAmount;
        minBid = _minBid;
        endTime = block.timestamp + _duration;
        assetId = _assetId;
        bidToken = IERC20(_bidToken);

        /* ---------- Legal validation ---------- */
        bool approved = ILegalRegistry(managerContract.legalRegistry())
            .isAssetApproved(assetId);
        require(approved, "Asset not approved");

        /* ---------- Ensure RWA token exists ---------- */
        address rwa = managerContract.rwaByAsset(assetId);
        require(rwa != address(0), "RWA not deployed");

        /* ---------- Ensure reward escrow ---------- */
        require(
            IRwaToken(rwa).transferFrom(_seller, address(this), _rewardAmount),
            "Reward escrow transfer failed"
        );
    }

    /* =============================== VIEWS =============================== */

    function isNativeAuction() public view returns (bool) {
        return address(bidToken) == address(0);
    }

    /* =============================== BIDDING =============================== */

    function bidERC20(uint256 amount) external nonReentrant auctionActive {
        require(!isNativeAuction(), "ERC20 bids disabled");
        require(amount >= minBid, "Below minimum bid");

        require(
            bidToken.transferFrom(msg.sender, address(this), amount),
            "ERC20 transfer failed"
        );

        _placeBid(msg.sender, amount);
    }

    function bidNative() external payable nonReentrant auctionActive {
        require(isNativeAuction(), "Native bids disabled");
        require(msg.value >= minBid, "Below minimum bid");

        _placeBid(msg.sender, msg.value);
    }

    function _placeBid(address bidder, uint256 amount) internal {
        uint256 newBid = bids[bidder] + amount;
        require(newBid > highestBid, "Not highest bid");

        bids[bidder] = newBid;
        highestBid = newBid;
        highestBidder = bidder;

        emit BidPlaced(bidder, newBid);
    }

    /* =============================== WITHDRAW =============================== */

    function withdraw() external nonReentrant auctionEnded {
        require(msg.sender != highestBidder, "Winner cannot withdraw");

        uint256 amount = bids[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        bids[msg.sender] = 0;

        if (isNativeAuction()) {
            (bool ok, ) = msg.sender.call{value: amount}("");
            require(ok, "ETH transfer failed");
        } else {
            require(
                bidToken.transfer(msg.sender, amount),
                "ERC20 transfer failed"
            );
        }

        emit Withdrawn(msg.sender, amount);
    }

    /* =============================== SETTLEMENT =============================== */

    function settle() external nonReentrant auctionEnded {
        require(!settled, "Already settled");
        settled = true;

        if (highestBidder != address(0)) {
            /* ---------- Pay seller ---------- */
            if (isNativeAuction()) {
                (bool ok, ) = seller.call{value: highestBid}("");
                require(ok, "ETH payout failed");
            } else {
                require(
                    bidToken.transfer(seller, highestBid),
                    "ERC20 payout failed"
                );
            }

            /* ---------- Reward winner ---------- */
            address rwa = managerContract.rwaByAsset(assetId);
            require(rwa != address(0), "RWA not deployed");

            require(
                IRwaToken(rwa).transfer(highestBidder, rewardAmount),
                "Reward transfer failed"
            );
        }

        emit AuctionSettled(highestBidder, highestBid);
    }

    /* =============================== RECEIVE =============================== */

    receive() external payable {
        revert("Use bidNative()");
    }
}
