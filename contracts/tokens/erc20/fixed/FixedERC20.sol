// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import '../ERC20.sol';

/// @notice ERC-20 with fixed supply.
contract FixedERC20 is ERC20 {
    constructor(
        string memory name_, 
        string memory symbol_, 
        uint8 decimals_, 
        address owner_,
        uint256 supply_
    ) ERC20(name_, symbol_, decimals_) {
        _mint(owner_, supply_);
    }
}
