// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice Minimal ERC-20 interface.
interface IERC20minimal { 
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function burnFrom(address from, uint256 amount) external;
}
