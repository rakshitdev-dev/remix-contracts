// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

contract MYReferral is IReferral, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address user => address referrer) private _user2Referrer; // upline
    mapping(address referrer => address[]) private _referrals; // direct referrals or count
    mapping(address referrer => uint256) private _referralRewards;
    mapping(address handler => bool) private _isHandler;

    bool public isInitialized;
    uint256 public totalReferralBonusReward;
    uint256 public totalReferralBonusAllocation;
    uint8 public rewardPercentage = 10;

    IERC20 public rewardToken;

    constructor() Ownable(_msgSender()) {}

    function initialize(
        address rewardToken_,
        uint256 totalReferralBonusAllocation_,
        address initialHandler_ // might be ico
    ) external onlyOwner {
        if (isInitialized) {
            revert AlreadyInitialize();
        }
        if (rewardToken_ == address(0) || initialHandler_ == address(0)) {
            revert InvalidAddress();
        }
        isInitialized = true;
        rewardToken = IERC20(rewardToken_);
        _isHandler[initialHandler_] = true;
        address _caller = _msgSender();
        rewardToken.safeTransferFrom(
            _caller,
            address(this),
            totalReferralBonusAllocation_
        );
        totalReferralBonusAllocation = totalReferralBonusAllocation_;
    }

    function _onlyHandler() private view {
        address caller = _msgSender();
        if (!_isHandler[caller]) {
            revert UnauthorizedHandler(caller);
        }
    }

    function updateHandler(
        address handler_,
        bool isEnable_
    ) external onlyOwner {
        _isHandler[handler_] = isEnable_;
    }

    function addReferral(address user_, address referrer_) external {
        if (!isInitialized) {
            revert NotInitialize();
        }
        _onlyHandler();
        if (_user2Referrer[user_] == address(0)) {
            _user2Referrer[user_] = referrer_;
            _referrals[referrer_].push(user_);
            emit ReferralAdded(user_, referrer_);
        }
    }

    function distributeRewards(
        address account_,
        uint256 tokenAmount_
    ) external nonReentrant {
        _onlyHandler();
        address referrer_ = getReferrer(account_);
        uint256 rewardToken_ = (tokenAmount_ * rewardPercentage) / 1e2;
        if (rewardToken_ > totalReferralBonusAllocation) {
            revert InsufficientRewardToken();
        }
        if (rewardToken_ != 0) {
            _referralRewards[referrer_] += rewardToken_;
            rewardToken.safeTransfer(referrer_, rewardToken_);
            emit ReferralReward(account_, referrer_, rewardToken_);
            totalReferralBonusAllocation -= rewardToken_;
            totalReferralBonusReward += rewardToken_;
        }
    }

    function getReferrer(address user_) public view returns (address) {
        return _user2Referrer[user_];
    }

    function getReferralsCount(
        address referrer_
    ) public view returns (uint256) {
        return _referrals[referrer_].length;
    }

    function updateRewardPercentage(uint8 _rewardPercentage) external {
        rewardPercentage = _rewardPercentage;
    }

    function getDirectReferrals(
        address referrer_,
        uint256 startIndex_,
        uint256 endIndex_
    ) public view returns (address[] memory users) {
        if (
            startIndex_ > endIndex_ || endIndex_ > getReferralsCount(referrer_)
        ) {
            revert InvalidRange(startIndex_, endIndex_);
        }
        uint256 length = endIndex_ - startIndex_;
        users = new address[](length);
        uint256 currentIndex;
        for (uint256 i = startIndex_; i < endIndex_; ) {
            users[currentIndex] = _referrals[referrer_][i];
            ++currentIndex;
            unchecked {
                ++i;
            }
        }
    }

    function getReferralRewards(
        address referrer_
    ) external view returns (uint256) {
        return _referralRewards[referrer_];
    }

    function transferRewardToken(
        address account_,
        uint256 amount_
    ) external onlyOwner {
        rewardToken.safeTransfer(account_, amount_);
    }
}
