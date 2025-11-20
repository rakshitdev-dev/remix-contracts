// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IReferral {
    error ReferralAlreadyExists();
    error InvalidReferrer();
    error UnauthorizedHandler(address handler);
    error InvalidAddress();
    error InvalidRange(uint256 startIndex, uint256 endIndex);
    error AlreadyInitialize();
    error NotInitialize();
    error InsufficientRewardToken();

    event ReferralAdded(address indexed user, address indexed referrer);
    event ReferralReward(
        address indexed user,
        address indexed referrer,
        uint256 reward
    );

    function addReferral(address account_, address referrer_) external;
    function distributeRewards(address account_, uint256 tokenAmount_) external;
    function getReferrer(
        address user_
    ) external view returns (address referrer);
    function getReferralsCount(
        address referrer_
    ) external view returns (uint256);
    function getReferralRewards(
        address referrer_
    ) external view returns (uint256);
    function getDirectReferrals(
        address referrer_,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (address[] memory users);
}

interface ISRXICO {
    error SaleTypeAlreadyCreated(SaleType saleType);
    error InsufficientSaleQuantity();
    error SaleNotLive(Status currentStatus);
    error SaleEnded();
    error InvalidRange(uint256 startIndex, uint256 endIndex);
    error MinBuyExceedsTotalSaleValue(
        uint256 minBuyUsd,
        uint256 totalSaleValueUsd
    );
    error MinBuyLimit(uint256 minBuy, uint256 given);
    error MaxBuyLimit(uint256 maxBuy, uint256 given);
    error EndTimeGreaterThanStart();
    error InvalidPriceFromOracle();
    error UnsupportedPaymentOptions();
    error NoTokensToBurn();
    error SaleNotEnded();
    error UnsoldTokenNotBurnable();
    error PriceFeedAddressMust();
    error InvalidOptionForTokenReceive();
    error AlreadyInitialize();
    error NotInitialize();
    error InvalidAddress();
    error NoClaimableBeforeLaunch();

    event BuyToken(
        address indexed user,
        address indexed referrer,
        uint256 amount,
        uint256 volume,
        SaleType saleType
    );
    event PaymentOptionUpdated(
        address indexed token,
        address indexed priceFeedAddress,
        bool enable,
        bool isStable
    );

    enum SaleType {
        PreSale,
        PrivateSale,
        PublicSale
    }

    enum Status {
        Upcoming,
        Live,
        Ended
    }

    enum SaleTokenOption {
        InstantTokenReceive,
        TokenReceiveAfterSaleEnd
    }

    struct ICO {
        uint256 saleRateInUsd;
        uint256 saleTokenAmount;
        uint256 saleQuantity;
        uint256 minBuyInUsd;
        uint256 maxBuyInUsd;
        SaleTokenOption saleTokenOption;
        uint256 startAt; // the time till when sale startAt - (in unix time)
        uint256 endAt; // the time till when sale endAt - (in unix time)
        Status status;
    }

    struct Contributor {
        address user;
        string coin; // token symbol
        uint256 amount; // usd
        uint256 volume; // token amount(quantity)
        uint256 at;
    }

    struct PaymentOption {
        address token;
        bool enable;
        bool isStable;
        address priceFeedAddress;
    }

    struct Claimable {
        uint256 amount; /// will claim amount
        uint256 claimed; /// after claimed
    }

    function saleType2IcoDetail(
        SaleType saleType_
    ) external view returns (ICO memory);
    function user2SaleType2ContributorList(
        address user_,
        SaleType saleType_,
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (Contributor[] memory);
    function user2SaleType2Contributor(
        address user_,
        SaleType saleType_
    ) external view returns (Contributor memory);
}

interface ICoinPredictionStaking {
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 claimedRewards;
        bool active;
        uint256 stakeApr;
        address stakeBy;
    }

    struct PendingReward {
        bool stakeStatus;
        bool unstakable;
        uint256 pendingReward;
    }

    // --- View Functions ---
    function token() external view returns (address);

    function unlocked() external view returns (bool);

    function apr() external view returns (uint256);

    function minStakeDuration() external view returns (uint256);

    function maxStakeDuration() external view returns (uint256);

    function getUserStakesCount(address user) external view returns (uint256);

    function getUserStakes(address user) external view returns (Stake[] memory);

    function getUserPendingReward(
        address user
    ) external view returns (PendingReward[] memory);

    // --- Core Actions ---
    function stake(uint256 amount, address stakeFor, address stakeBy) external;

    function claimReward(uint256 index) external;

    function unstake(uint256 index) external;

    // --- Admin ---
    function setMinDuration(uint256 newMinDurationYears) external;

    function setMaxDuration(uint256 newMaxDurationYears) external;

    function setApr(uint256 newAprBasisPoints) external;

    function withdrawUnusedTokens() external;

    function transferOwnership(address newOwner) external;

    function toggleLock() external;
}

contract MYICO is ISRXICO, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(SaleType saleType => ICO) private _saleType2IcoDetail;
    mapping(SaleType saleType => address[]) private _saleType2Contributors;
    mapping(address user => mapping(SaleType saleType => Contributor[]))
        private _user2SaleType2ContributorList;
    mapping(address user => mapping(SaleType saleType => Contributor))
        private _user2SaleType2Contributor;
    mapping(address token => PaymentOption) private _paymentOption; /// if zero address true then  Native Coin
    mapping(address user => mapping(SaleType saleType => Claimable))
        private _user2SaleType2ClaimableDetail;
    address[] private _acceptedTokens;

    bool public isInitialized;
    IERC20 public saleToken;
    IReferral public referralContract;
    ICoinPredictionStaking public stakingContract;

    uint8 private constant _NATIVE_COIN_DECIMALS = 18; // EVM only
    uint256 public exchangelaunchDate;

    constructor() Ownable(_msgSender()) {}

    function initialize(
        address saleToken_,
        address referralContract_,
        address stakeAddress_
    ) public onlyOwner {
        if (isInitialized) {
            revert AlreadyInitialize();
        }
        if (saleToken_ == address(0) || referralContract_ == address(0)) {
            revert InvalidAddress();
        }
        isInitialized = true;
        exchangelaunchDate = 1803902400; /// 1st March 2027
        saleToken = IERC20(saleToken_);
        referralContract = IReferral(referralContract_);
        stakingContract = ICoinPredictionStaking(stakeAddress_);
    }

    function updatereferralContract(
        address referralContract_
    ) public onlyOwner {
        referralContract = IReferral(referralContract_);
    }

    function updateExchangelaunchDate(
        uint256 exchangelaunchDate_
    ) public onlyOwner {
        exchangelaunchDate = exchangelaunchDate_;
    }

    function saleType2IcoDetail(
        SaleType saleType_
    ) public view returns (ICO memory) {
        return _saleType2IcoDetail[saleType_];
    }

    function totalContributorLengthForUser(
        address user_,
        SaleType saletType_
    ) public view returns (uint256) {
        return _user2SaleType2ContributorList[user_][saletType_].length;
    }

    function totalContributor(
        SaleType saletType_
    ) public view returns (uint256) {
        return _saleType2Contributors[saletType_].length;
    }

    function user2SaleType2Contributor(
        address user_,
        SaleType saleType_
    ) public view returns (Contributor memory) {
        return _user2SaleType2Contributor[user_][saleType_];
    }

    function user2SaleType2ContributorList(
        address user_,
        SaleType saletType_,
        uint256 startIndex_,
        uint256 endIndex_
    ) public view returns (Contributor[] memory result) {
        if (
            startIndex_ > endIndex_ ||
            endIndex_ > totalContributorLengthForUser(user_, saletType_)
        ) {
            revert InvalidRange(startIndex_, endIndex_);
        }
        uint256 length = endIndex_ - startIndex_;
        result = new Contributor[](length);

        uint256 currentIndex;
        for (uint256 i = startIndex_; i < endIndex_; ) {
            result[currentIndex] = _user2SaleType2ContributorList[user_][
                saletType_
            ][i];
            ++currentIndex;
            unchecked {
                ++i;
            }
        }
    }

    function saleType2Contributors(
        SaleType saletType_,
        uint256 startIndex_,
        uint256 endIndex_
    ) public view returns (address[] memory result) {
        if (
            startIndex_ > endIndex_ || endIndex_ > totalContributor(saletType_)
        ) {
            revert InvalidRange(startIndex_, endIndex_);
        }
        uint256 length = endIndex_ - startIndex_;
        result = new address[](length);

        uint256 currentIndex;
        for (uint256 i = startIndex_; i < endIndex_; ) {
            result[currentIndex] = _saleType2Contributors[saletType_][i];
            ++currentIndex;
            unchecked {
                ++i;
            }
        }
    }

    function user2SaleType2ClaimableDetail(
        address user_,
        SaleType saleType_
    ) public view returns (Claimable memory) {
        return _user2SaleType2ClaimableDetail[user_][saleType_];
    }

    function getAcceptedTokenList() public view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _acceptedTokens.length; ) {
            if (_paymentOption[_acceptedTokens[i]].enable) {
                ++count;
            }
            unchecked {
                ++i;
            }
        }

        address[] memory enabledTokens = new address[](count);
        if (count == 0) {
            return enabledTokens;
        }
        uint256 index = 0;
        for (uint256 i = 0; i < _acceptedTokens.length; ) {
            if (_paymentOption[_acceptedTokens[i]].enable) {
                enabledTokens[index] = _acceptedTokens[i];
                ++index;
            }
            unchecked {
                ++i;
            }
        }

        return enabledTokens;
    }

    function getPaymentOption(
        address token_
    ) public view returns (PaymentOption memory) {
        return _paymentOption[token_];
    }

    function setPaymentOption(
        address token_,
        address priceFeedAddress_,
        bool enable_,
        bool isStable_
    ) public onlyOwner {
        if (
            (token_ == address(0) || !isStable_) &&
            priceFeedAddress_ == address(0)
        ) {
            revert PriceFeedAddressMust();
        }

        if (_paymentOption[token_].token != token_ && token_ != address(0)) {
            _acceptedTokens.push(token_);
        }
        _paymentOption[token_] = PaymentOption({
            token: token_,
            enable: enable_,
            isStable: isStable_,
            priceFeedAddress: priceFeedAddress_
        });
        emit PaymentOptionUpdated(
            token_,
            priceFeedAddress_,
            enable_,
            isStable_
        );
    }

    function createSale(
        SaleType saleType_,
        uint256 saleRateInUsd_,
        uint256 saleTokenAmount_,
        uint256 minBuyInUsd_,
        uint256 maxBuyInUsd_,
        SaleTokenOption saleTokenOption_,
        uint256 startAt_,
        uint256 endAt_
    ) public onlyOwner {
        if (!isInitialized) {
            revert NotInitialize();
        }
        if (saleType2IcoDetail(saleType_).saleTokenAmount != 0) {
            revert SaleTypeAlreadyCreated(saleType_);
        }
        if (endAt_ < startAt_) {
            revert EndTimeGreaterThanStart();
        }

        if (minBuyInUsd_ > saleRateInUsd_ * saleTokenAmount_) {
            revert MinBuyExceedsTotalSaleValue(
                minBuyInUsd_,
                saleRateInUsd_ * saleTokenAmount_
            );
        }
        address _caller = _msgSender();
        saleToken.safeTransferFrom(_caller, address(this), saleTokenAmount_);

        _saleType2IcoDetail[saleType_] = ICO({
            saleRateInUsd: saleRateInUsd_,
            saleTokenAmount: saleTokenAmount_,
            saleQuantity: saleTokenAmount_,
            minBuyInUsd: minBuyInUsd_,
            maxBuyInUsd: maxBuyInUsd_,
            saleTokenOption: saleTokenOption_,
            startAt: startAt_ != 0 ? startAt_ : block.timestamp,
            endAt: endAt_,
            status: startAt_ != 0 ? Status.Upcoming : Status.Live
        });
    }

    function updateSaleTime(
        SaleType saleType_,
        uint256 startAt_,
        uint256 endAt_
    ) public onlyOwner {
        if (endAt_ < startAt_) {
            revert EndTimeGreaterThanStart();
        }
        _saleType2IcoDetail[saleType_].endAt = endAt_;
        if (startAt_ != 0) {
            _saleType2IcoDetail[saleType_].startAt = startAt_;
            _saleType2IcoDetail[saleType_].status = Status.Upcoming;
        } else {
            _saleType2IcoDetail[saleType_].startAt = block.timestamp;
            _saleType2IcoDetail[saleType_].status = Status.Live;
        }
    }

    function buy(
        SaleType saleType_,
        address token_,
        uint256 amount_,
        address referrer_,
        address user_ 
    ) public payable nonReentrant {
        if (!getPaymentOption(token_).enable) {
            revert UnsupportedPaymentOptions();
        }
        ICO memory saleDetail_ = saleType2IcoDetail(saleType_);
        if (saleDetail_.startAt > block.timestamp) {
            revert SaleNotLive(saleDetail_.status);
        }
        if (block.timestamp > saleDetail_.endAt) {
            revert SaleEnded();
        }
        uint256 amountInUsd_ = getPaymentOption(token_).isStable
            ? amount_
            : calculateUSDAmount(
                token_,
                token_ != address(0) ? amount_ : msg.value
            );
        if (amountInUsd_ == 0) {
            revert InvalidPriceFromOracle();
        }
        token_ != address(0)
            ? _buyWithToken(
                saleDetail_,
                saleType_,
                user_,
                token_,
                amount_,
                amountInUsd_,
                referrer_
            )
            : _buyWithNativeCoin(
                saleDetail_,
                saleType_,
                user_,
                amountInUsd_,
                referrer_
            );
    }

    function _buyWithToken(
        ICO memory saleDetail_,
        SaleType saleType_,
        address account_,
        address token_,
        uint256 amount_,
        uint256 amountInUsd_,
        address referrer_
    ) private {
        if (amountInUsd_ < saleDetail_.minBuyInUsd) {
            revert MinBuyLimit(saleDetail_.minBuyInUsd, amountInUsd_);
        }

        if (amountInUsd_ > saleDetail_.maxBuyInUsd) {
            revert MaxBuyLimit(saleDetail_.maxBuyInUsd, amountInUsd_);
        }

        uint256 tokenAmount_ = (amountInUsd_ * 1e18) /
            getSaleTokenPrice(saleType_);

        if (saleDetail_.saleQuantity < tokenAmount_) {
            revert InsufficientSaleQuantity();
        }
        if (saleToken.balanceOf(address(this)) < tokenAmount_) {
            revert("Insufficient: SaleToken");
        }
        IERC20(token_).safeTransferFrom(account_, address(this), amount_);

        _saleType2IcoDetail[saleType_].saleQuantity -= tokenAmount_;

        if (_user2SaleType2Contributor[account_][saleType_].amount == 0) {
            _saleType2Contributors[saleType_].push(account_);
        }

        _user2SaleType2ContributorList[account_][saleType_].push(
            Contributor({
                user: account_,
                coin: IERC20Metadata(token_).symbol(),
                amount: amountInUsd_,
                volume: tokenAmount_,
                at: block.timestamp
            })
        );

        _user2SaleType2Contributor[account_][saleType_].amount += amountInUsd_;
        _user2SaleType2Contributor[account_][saleType_].volume += tokenAmount_;

        _saleTokenTransferOptions(
            saleDetail_,
            saleType_,
            account_,
            tokenAmount_
        );
        emit BuyToken(account_, referrer_, amount_, tokenAmount_, saleType_);

        if (referrer_ != address(0) && referrer_ != account_) {
            referralContract.addReferral(account_, referrer_);
            referralContract.distributeRewards(account_, tokenAmount_);
        }
    }

    function _buyWithNativeCoin(
        ICO memory saleDetail_,
        SaleType saleType_,
        address account_,
        uint256 amountInUsd_,
        address referrer_
    ) private {
        if (amountInUsd_ < saleDetail_.minBuyInUsd) {
            revert MinBuyLimit(saleDetail_.minBuyInUsd, amountInUsd_);
        }

        if (amountInUsd_ > saleDetail_.maxBuyInUsd) {
            revert MaxBuyLimit(saleDetail_.maxBuyInUsd, amountInUsd_);
        }

        uint256 tokenAmount_ = (amountInUsd_ * 1e18) /
            getSaleTokenPrice(saleType_);

        if (saleDetail_.saleQuantity < tokenAmount_) {
            revert InsufficientSaleQuantity();
        }
        if (saleToken.balanceOf(address(this)) < tokenAmount_) {
            revert("Insufficient: SaleToken");
        }
        _saleType2IcoDetail[saleType_].saleQuantity -= tokenAmount_;

        if (_user2SaleType2Contributor[account_][saleType_].amount == 0) {
            _saleType2Contributors[saleType_].push(account_);
        }

        _user2SaleType2ContributorList[account_][saleType_].push(
            Contributor({
                user: account_,
                coin: "Native",
                amount: amountInUsd_,
                volume: tokenAmount_,
                at: block.timestamp
            })
        );

        _user2SaleType2Contributor[account_][saleType_].amount += amountInUsd_;
        _user2SaleType2Contributor[account_][saleType_].volume += tokenAmount_;

        _saleTokenTransferOptions(
            saleDetail_,
            saleType_,
            account_,
            tokenAmount_
        );
        emit BuyToken(account_, referrer_, msg.value, tokenAmount_, saleType_);

        if (referrer_ != address(0) && referrer_ != account_) {
            referralContract.addReferral(account_, referrer_);
            referralContract.distributeRewards(account_, tokenAmount_);
        }
    }

    // function _saleTokenTransferOptions(
    //     address account_,
    //     uint256 tokenAmount_
    // ) private {
    //     saleToken.safeTransfer(account_, tokenAmount_);
    // }
    function _saleTokenTransferOptions(
        ICO memory saleDetail_,
        SaleType saleType_,
        address account_,
        uint256 tokenAmount_
    ) private {
        if (
            saleDetail_.saleTokenOption == SaleTokenOption.InstantTokenReceive
        ) {
            // Direct transfer
            // saleToken.safeTransfer(account_, tokenAmount_);
            bool success = saleToken.approve(
                address(stakingContract),
                tokenAmount_
            );
            require(success, "TOKEN_APPROVE_FAILED");

            stakingContract.stake(tokenAmount_, account_, address(this));
        } else {
            // Store claimable for later (single fallback condition)
            _user2SaleType2ClaimableDetail[account_][saleType_]
                .amount += tokenAmount_;
        }
    }

    function claimSaleToken(SaleType saleType_) public nonReentrant {
        ICO memory saleDetail_ = saleType2IcoDetail(saleType_);
        /// Check if the sale has ended
        if (block.timestamp < saleDetail_.endAt) {
            revert SaleNotEnded();
        }
        address caller_ = _msgSender();
        Claimable memory claimable_ = user2SaleType2ClaimableDetail(
            caller_,
            saleType_
        );
        uint256 _remainingToken = claimable_.amount - claimable_.claimed;
        if (_remainingToken == 0) {
            revert("claimed");
        }
        if (
            saleDetail_.saleTokenOption ==
            SaleTokenOption.TokenReceiveAfterSaleEnd
        ) {
            _user2SaleType2ClaimableDetail[caller_][saleType_]
                .claimed = claimable_.amount;
            // saleToken.safeTransfer(caller_, claimable_.amount);
            bool success = saleToken.approve(
                address(stakingContract),
                claimable_.amount
            );
            require(success, "TOKEN_APPROVE_FAILED");

            stakingContract.stake(claimable_.amount, caller_, address(this));
        } else {
            revert InvalidOptionForTokenReceive();
        }
    }

    function calculateUSDAmount(
        address token_,
        uint256 amount_
    ) public view returns (uint256 usdAmount) {
        if (!getPaymentOption(token_).enable) {
            return 0;
        }
        /// Get price data for the token
        (int256 price_, uint8 priceDecimals_) = getPriceFromOracle(token_);
        uint256 priceUint_ = uint256(price_);

        /// Calculate USD amount with proper decimal handling
        /// Formula: (amount_ * price_) / (10 ^ tokenDecimal_)
        /// We ensure high precision by multiplying first
        uint8 decimals_ = (
            token_ != address(0)
                ? IERC20Metadata(token_).decimals()
                : _NATIVE_COIN_DECIMALS
        );
        usdAmount = (amount_ * priceUint_) / (10 ** decimals_);

        /// If the price decimals don't match our standard _PRICE_DECIMAL,
        /// adjust the result accordingly
        if (priceDecimals_ > decimals_) {
            usdAmount = usdAmount / (10 ** (priceDecimals_ - decimals_));
        } else if (priceDecimals_ < decimals_) {
            usdAmount = usdAmount * (10 ** (decimals_ - priceDecimals_));
        }
        return usdAmount;
    }

    function getSaleTokenPrice(
        SaleType saleType_
    ) public view returns (uint256) {
        ICO memory saleDetail_ = _saleType2IcoDetail[saleType_];

        // uint256 currentTime_ = block.timestamp;

        // /// Time elapsed since the sale started or until the sale ended
        // uint256 effectiveTime_ = currentTime_ > saleDetail_.endAt ? saleDetail_.endAt : currentTime_;
        // uint256 timeElapsed = effectiveTime_ > saleDetail_.startAt ? effectiveTime_ - saleDetail_.startAt : 0;

        // /// Adjusted sale rate after applying the percentage change for each interval
        uint256 adjustedSaleRate_ = saleDetail_.saleRateInUsd;

        // /// Apply rate change if both percentage and duration are set
        // if (saleDetail_.maxBounceInPercent != 0 && saleDetail_.decreseBouncePerDayInPercent !=0) {
        //     uint256 intervals = timeElapsed / saleDetail_.decreseBouncePerDayInPercent;
        //     for (uint256 i = 0; i < intervals;) {
        //         adjustedSaleRate_ += (saleDetail_.saleRateInUsd * saleDetail_.maxBounceInPercent) / 1e4;
        //         unchecked {
        //             ++i;
        //         }
        //     }
        // }
        return adjustedSaleRate_;
    }

    function getPriceFromOracle(
        address token_
    ) public view returns (int256 price, uint8 decimals) {
        address priceFeedAddress_ = _paymentOption[token_].priceFeedAddress;
        if (priceFeedAddress_ == address(0)) {
            return (0, 0);
        }
        AggregatorV3Interface priceFeed_ = AggregatorV3Interface(
            priceFeedAddress_
        );
        (, int256 latestPrice_, , , ) = priceFeed_.latestRoundData();

        return (latestPrice_, priceFeed_.decimals());
    }

    function transferTokens(
        IERC20 token_,
        address to_,
        uint256 amount_
    ) public onlyOwner {
        token_.safeTransfer(to_, amount_);
    }

    function transferNativeCoin(
        address payable to_,
        uint256 amount_
    ) public onlyOwner {
        (bool success, ) = to_.call{value: amount_}("");
        if (!success) {
            revert("Tx:Failed");
        }
    }

    receive() external payable {}
}
