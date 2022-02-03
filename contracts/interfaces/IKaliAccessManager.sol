// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice Kali DAO access manager interface.
interface IKaliAccessManager {
    function listedAccounts(uint256 listId, address account) external returns (bool);
}
