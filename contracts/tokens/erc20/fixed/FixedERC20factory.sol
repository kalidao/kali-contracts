// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import './FixedERC20.sol';

/// @notice Factory for ERC-20 with fixed supply.
contract FixedERC20factory {
    event TokenDeployed(string indexed name, ERC20 indexed fixedERC20);
    
    function deployFixedERC20(
        string memory name_, 
        string memory symbol_, 
        uint8 decimals_, 
        address owner_,
        uint256 supply_
    ) external returns (FixedERC20 fixedERC20) {
        fixedERC20 = new FixedERC20(
            name_, 
            symbol_, 
            decimals_, 
            owner_,
            supply_
        );
        
        emit TokenDeployed(name_, fixedERC20);
    }
}
