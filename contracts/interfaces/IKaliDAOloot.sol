// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice Kali DAO loot interface.
interface IKaliDAOloot { 
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function deployKaliDAOloot(
        string memory name_,
        string memory symbol_,
        bool paused_,
        address[] memory accounts_,
        uint256[] memory loots_,
        address owner_
    ) external returns (address kaliDAOloot);

    function ownerBurn(address from, uint256 amount) external;
}
