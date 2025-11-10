// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StableCoin is ERC20, Ownable, ERC20Burnable {
    constructor(uint256 initialSupply) ERC20("Test", "Test") Ownable(msg.sender){
        _mint(msg.sender, initialSupply);
    }

    function mint(address account_, uint256 amount_) public onlyOwner {
        _mint(account_, amount_);
    }
}