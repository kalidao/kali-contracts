// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice Ricardian LLC formation interface.
interface IRicardianLLC {
    function mintLLC(address to) external payable;
}
