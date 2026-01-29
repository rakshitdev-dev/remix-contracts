// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor(uint256 _totalSupply) ERC20("MyToken", "MTK") {
        _mint(msg.sender, _totalSupply * 10 ** decimals());
    }
}
