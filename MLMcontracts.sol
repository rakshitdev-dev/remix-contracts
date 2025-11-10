// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MLM {
    uint256 public constant LEVELS = 3;

    // Commission rates for each level (in percentage)
    uint256[LEVELS] public commissionRates = [50, 30, 20];

    mapping(address => address) public upline;
    mapping(address => address[]) public downlines;
    mapping(address => uint256) public earnings;
    mapping(address => bool) public isRegistered;

    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "Not registered");
        _;
    }

    function register(address _referrer) external {
        require(!isRegistered[msg.sender], "Already registered");
        require(_referrer != msg.sender, "Self-referral not allowed");
        require(_referrer == address(0) || isRegistered[_referrer], "Referrer not registered");

        isRegistered[msg.sender] = true;
        upline[msg.sender] = _referrer;

        if (_referrer != address(0)) {
            downlines[_referrer].push(msg.sender);
        }
    }

    function buy() external payable onlyRegistered {
        require(msg.value > 0, "Must pay something");

        address currentUpline = upline[msg.sender];

        for (uint256 i = 0; i < LEVELS; i++) {
            if (currentUpline == address(0)) {
                break;
            }

            uint256 commission = (msg.value * commissionRates[i]) / 100;
            earnings[currentUpline] += commission;

            currentUpline = upline[currentUpline];
        }
    }

    function withdraw() external {
        uint256 amount = earnings[msg.sender];
        require(amount > 0, "No earnings");
        earnings[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function getDownlines(address _user) external view returns (address[] memory) {
        return downlines[_user];
    }
}
