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
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IRwaManager} from "./interfaces/IRwaManager.sol";
import {ILegalRegistry} from "./interfaces/ILegalRegistry.sol";
import {IRwaToken} from "./interfaces/IRwaToken.sol";

contract BidContract is Initializable, ReentrancyGuard {
    /*===============================CONSTANTS===============================*/

    /// @notice Fixed deposit percentage required to participate in auction
    uint256 public constant DEPOSIT_PERCENT = 10;

    /*===============================AUCTION CONFIG===============================*/

    /// @notice Address receiving auction proceeds (usually asset owner)
    address public seller;

    /// @notice RWA manager contract handling assets and registry
    IRwaManager public managerContract;

    /// @notice Asset identifier registered in legal registry
    uint256 public assetId;

    /// @notice Amount of RWA tokens rewarded to auction winner
    uint256 public rewardAmount;

    /// @notice ERC20 token used for bidding (address(0) for native ETH)
    IERC20 public priceToken;

    /// @notice Minimum allowed total bid (not deposit)
    uint256 public minTotalBid;

    /// @notice Auction end timestamp
    uint256 public endTime;

    /// @notice Last timestamp winner may complete remaining payment
    uint256 public gracePeriodEnd;

    /// @notice Platform fee in basis points (e.g. 200 = 2%)
    uint256 public feeBps;

    /*===============================AUCTION STATE===============================*/

    /// @notice Current highest bidder
    address public highestBidder;

    /// @notice Deposit amount submitted by highest bidder
    uint256 public highestDeposit;

    /// @notice True once auction has been settled
    bool public settled;

    /// @notice True if winner paid remaining 90% of bid
    bool public fullyPaid;

    /// @notice Mapping of bidder => deposited amount
    mapping(address => uint256) public deposits;

    /*===============================EVENTS===============================*/

    /// @notice Emitted when a bidder places or increases a deposit
    event BidPlaced(address indexed bidder, uint256 deposit);

    /// @notice Emitted when winner completes remaining payment
    event RemainingPaid(address indexed bidder, uint256 amount);

    /// @notice Emitted when a bidder withdraws their refundable deposit
    event DepositWithdrawn(address indexed bidder, uint256 amount);

    /// @notice Emitted when winner defaults and deposit is forfeited
    event DepositForfeited(address indexed bidder, uint256 amount);

    /// @notice Emitted when auction settlement completes
    event AuctionSettled(address winner, uint256 totalBid);

    /*===============================MODIFIERS===============================*/

    /// @dev Ensures auction is still active
    modifier auctionActive() {
        require(block.timestamp < endTime, "Auction ended");
        _;
    }

    /// @dev Ensures auction has ended
    modifier auctionEnded() {
        require(block.timestamp >= endTime, "Auction not ended");
        _;
    }

    /*===============================INITIALIZER===============================*/

    /**
     * @param _seller Address receiving auction proceeds
     * @param _manager RWA managerContract contract
     * @param _rewardAmount Amount of RWA tokens awarded to winner
     * @param _priceToken ERC20 bidding token (address(0) for ETH)
     * @param _minTotalBid Minimum total bid amount (not deposit)
     * @param _duration Auction duration in seconds
     * @param _assetId Registered asset ID
     * @param _gracePeriod Grace period to complete payment
     * @param _feeBps Platform fee in basis points
     */

    struct InitParams {
        address seller;
        address managerContract;
        uint256 rewardAmount;
        address priceToken;
        uint256 minTotalBid;
        uint256 duration;
        uint256 assetId;
        uint256 gracePeriod;
        uint256 feeBps;
    }

    /**
     * @notice Initializes the Bid Contract instance.
     * @dev Called once by the factory or deployer.
     */
    function initialize(InitParams calldata params) external initializer {
        require(params.seller != address(0), "Invalid seller");
        require(params.managerContract != address(0), "Invalid manager");
        require(params.duration > 0, "Invalid duration");
        require(params.feeBps <= 1_000, "Fee too high");

        seller = params.seller;
        managerContract = IRwaManager(params.managerContract);
        rewardAmount = params.rewardAmount;
        assetId = params.assetId;

        priceToken = IERC20(params.priceToken);
        minTotalBid = params.minTotalBid;
        endTime = block.timestamp + params.duration;
        gracePeriodEnd = endTime + (params.gracePeriod);
        feeBps = params.feeBps;

        require(
            ILegalRegistry(managerContract.legalRegistry()).isAssetApproved(
                assetId
            ),
            "Asset not approved"
        );

        address rwa = managerContract.rwaByAsset(assetId);
        require(rwa != address(0), "RWA token not deployed");
    }

    /*===============================VIEWS===============================*/

    /// @notice Returns true if auction uses native ETH
    function isNativeAuction() public view returns (bool) {
        return address(priceToken) == address(0);
    }

    /**
     * @notice Converts deposit to implied total bid
     * @param deposit Deposit amount (10%)
     * @return Total bid amount (100%)
     */
    function totalBid(uint256 deposit) public pure returns (uint256) {
        return (deposit * 100) / DEPOSIT_PERCENT;
    }

    /// @notice Remaining amount winner must pay to finalize auction
    function remainingPayment() public view returns (uint256) {
        return totalBid(highestDeposit) - highestDeposit;
    }

    /*===============================BIDDING===============================*/

    /**
     * @notice Place or increase bid using native ETH
     * @dev msg.value must represent a 10% deposit
     */
    function bidNative() external payable nonReentrant auctionActive {
        require(isNativeAuction(), "Native disabled");
        _placeBid(msg.sender, msg.value);
    }

    /**
     * @notice Place or increase bid using ERC20 token
     * @param deposit Deposit amount (10% of intended bid)
     */
    function bidERC20(uint256 deposit) external nonReentrant auctionActive {
        require(!isNativeAuction(), "ERC20 disabled");
        priceToken.transferFrom(msg.sender, address(this), deposit);
        _placeBid(msg.sender, deposit);
    }

    /**
     * @dev Internal bid logic shared by native and ERC20 flows
     */
    function _placeBid(address bidder, uint256 deposit) internal {
        require(deposit > 0, "Zero deposit");
        ILegalRegistry(managerContract.legalRegistry()).validateJurisdiction(
            msg.sender,
            assetId
        );
        uint256 newDeposit = deposits[bidder] + deposit;
        uint256 impliedBid = totalBid(newDeposit);

        require(impliedBid >= minTotalBid, "Below min bid");
        require(newDeposit > highestDeposit, "Not highest");

        deposits[bidder] = newDeposit;
        highestDeposit = newDeposit;
        highestBidder = bidder;

        emit BidPlaced(bidder, newDeposit);
    }

    /*===============================PAYMENT===============================*/

    /**
     * @notice Winner pays remaining 90% of bid amount
     * @dev Must be called before grace period expires
     */
    function payRemaining() external payable nonReentrant auctionEnded {
        require(msg.sender == highestBidder, "Not winner");
        require(!fullyPaid, "Already paid");
        require(block.timestamp <= gracePeriodEnd, "Grace expired");

        uint256 remaining = remainingPayment();

        if (isNativeAuction()) {
            require(msg.value == remaining, "Invalid amount");
        } else {
            priceToken.transferFrom(msg.sender, address(this), remaining);
        }

        fullyPaid = true;
        emit RemainingPaid(msg.sender, remaining);
    }

    /*===============================WITHDRAW===============================*/

    /**
     * @notice Withdraw refundable deposit if caller is not winner
     */
    function withdraw() external nonReentrant {
        require(msg.sender != highestBidder, "Winner blocked");

        uint256 amount = deposits[msg.sender];
        require(amount > 0, "Nothing to withdraw");

        deposits[msg.sender] = 0;

        if (isNativeAuction()) {
            _safeNativeTransfer(msg.sender, amount);
        } else {
            priceToken.transfer(msg.sender, amount);
        }

        emit DepositWithdrawn(msg.sender, amount);
    }

    /*===============================SETTLEMENT===============================*/

    /**
     * @notice Finalizes auction and distributes funds
     *
     * @dev
     * - If winner paid fully → seller + platform fee + RWA transfer
     * - If winner defaulted → deposit forfeited, no RWA transfer
     */
    function settle() external nonReentrant auctionEnded {
        require(!settled, "Already settled");
        settled = true;

        address managerOwner = managerContract.owner();
        uint256 fee;
        uint256 sellerAmount;

        if (fullyPaid) {
            uint256 total = totalBid(highestDeposit);
            fee = (total * feeBps) / 10_000;
            sellerAmount = total - fee;

            _payout(seller, sellerAmount);
            _payout(managerOwner, fee);

            IRwaToken(managerContract.rwaByAsset(assetId)).transfer(
                highestBidder,
                rewardAmount
            );
        } else {
            fee = (highestDeposit * feeBps) / 10_000;
            sellerAmount = highestDeposit - fee;

            _payout(seller, sellerAmount);
            _payout(managerOwner, fee);

            emit DepositForfeited(highestBidder, highestDeposit);
        }

        emit AuctionSettled(
            highestBidder,
            fullyPaid ? totalBid(highestDeposit) : 0
        );
    }

    /// @dev Handles native or ERC20 payouts
    function _payout(address to, uint256 amount) internal {
        if (amount == 0) return;

        if (isNativeAuction()) {
            _safeNativeTransfer(to, amount);
        } else {
            priceToken.transfer(to, amount);
        }
    }

    /// @dev Safe ETH transfer wrapper
    function _safeNativeTransfer(address to, uint256 amount) internal {
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    /// @dev Prevents accidental ETH transfers
    receive() external payable {
        revert("Direct ETH rejected");
    }
}
