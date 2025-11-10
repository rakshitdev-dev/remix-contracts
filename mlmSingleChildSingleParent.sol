// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract SimpleMLM {
    address public manager;
    uint256 public productPrice = 80; // in wei or tokens depending on design
    uint256 public constant UPLINE_PERCENT = 10;
    uint256 public constant BUYER_PERCENT = 10;
    uint256 public constant MANAGER_PERCENT = 80;

    mapping(address => address) public upline;
    mapping(address => uint256) public earnings;

    constructor(address _manager) {
        require(_manager != address(0), "Manager cannot be zero");
        require(upline[_manager] == address(0), "Manager cannot be a registered person");
        manager = _manager;
    }

    // Register only (no payment here)
    function register(address _referrer) external {
        require(upline[msg.sender] == address(0), "Already registered");
        require(_referrer != msg.sender, "Cannot refer yourself");
        
        // If referrer not registered or zero — default to manager
        if (_referrer == address(0) || upline[_referrer] == address(0)) {
            _referrer = manager;
        }

        upline[msg.sender] = _referrer;
    }

    // Buy product and distribute commissions
    function buy() external payable {
        require(upline[msg.sender] != address(0), "Not registered");
        require(msg.value >= productPrice, "Insufficient payment");

        uint256 amount = msg.value;

        uint256 buyerCut = (amount * BUYER_PERCENT) / 100;
        uint256 uplineCut = (amount * UPLINE_PERCENT) / 100;
        uint256 managerCut = (amount * MANAGER_PERCENT) / 100;

        earnings[msg.sender] += buyerCut;
        earnings[upline[msg.sender]] += uplineCut;
        earnings[manager] += managerCut;
    }

    function withdraw() external {
        uint256 amount = earnings[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        earnings[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }
}
