// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice EIP-2612 interface.
interface IERC20Permit {
    function permit(
        address owner, 
        address spender, 
        uint256 value, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external;
}
