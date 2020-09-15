// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./ERC20.sol";

contract WinesToken is ERC20 {
    
    constructor () public {
        _totalSupply = 100000000 * 10 ** 18;
        name = "Wines token";
        symbol = "WINES";
        _balances[msg.sender] = _totalSupply;
    }
    
}