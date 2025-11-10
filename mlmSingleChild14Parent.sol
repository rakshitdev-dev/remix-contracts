// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SimpleMLM {
    address public manager;
    uint256 public productPrice = 80; // in wei
    uint256 public constant BUYER_PERCENT = 10;
    uint256 public constant MANAGER_PERCENT = 80;

    // Commission per upline level (14 levels)
    uint256[14] public levelCommission = [
        10, 9, 8, 7, 6, 5, 5, 4, 3, 3, 2, 2, 1, 1
    ];

    mapping(address => address) public upline;
    mapping(address => uint256) public earnings;

    constructor(address _manager) {
        require(_manager != address(0), "Manager cannot be zero");
        manager = _manager;
        upline[_manager] = address(0); // manager has no parent
    }

    function register(address _referrer) external {
        require(upline[msg.sender] == address(0), "Already registered");
        require(_referrer != msg.sender, "Cannot refer yourself");
        if (_referrer == address(0) || upline[_referrer] == address(0)) {
            _referrer = manager;
        }
        upline[msg.sender] = _referrer;
    }

    function buy() external payable {
        require(upline[msg.sender] != address(0), "Not registered");
        require(msg.value >= productPrice, "Insufficient payment");

        uint256 amount = msg.value;

        // Buyer cut
        uint256 buyerCut = (amount * BUYER_PERCENT) / 100;
        earnings[msg.sender] += buyerCut;

        // Pay uplines up to 14 levels
        address current = upline[msg.sender];
        for (uint256 i = 0; i < 14; i++) {
            if (current == address(0)) break; // no more uplines
            uint256 cut = (amount * levelCommission[i]) / 100;
            earnings[current] += cut;
            current = upline[current];
        }

        // Manager residual
        earnings[manager] += (amount * MANAGER_PERCENT) / 100;
    }

    function withdraw() external {
        uint256 amount = earnings[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        earnings[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}
