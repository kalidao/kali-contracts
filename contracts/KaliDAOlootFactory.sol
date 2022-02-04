// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import './KaliDAOloot.sol';

/// @notice Factory to deploy Kali DAO loot token.
contract KaliDAOlootFactory {
    error NullDeploy();

    address private immutable lootMaster;
 
    constructor(address lootMaster_) {
        lootMaster = lootMaster_;
    }
   
    function deployKaliDAOloot(
        string memory name_, 
        string memory symbol_, 
        bool paused_,
        address[] calldata accounts_,
        uint256[] calldata loots_,
        address owner_
    ) public virtual returns (KaliDAOloot kaliDAOloot) {
        string memory lootName_ = string(abi.encodePacked(name_, " LOOT"));
        string memory lootSymbol_ = string(abi.encodePacked(symbol_, "-LOOT"));

        kaliDAOloot = KaliDAOloot(_cloneAsMinimalProxy(lootMaster, lootName_));

        kaliDAOloot.init(
            lootName_,
            lootSymbol_,
            paused_,
            accounts_,
            loots_,
            owner_
        );
    }
 
    /// @dev modified from Aelin (https://github.com/AelinXYZ/aelin/blob/main/contracts/MinimalProxyFactory.sol)
    function _cloneAsMinimalProxy(address base, string memory name_) internal virtual returns (address clone) {
        bytes memory createData = abi.encodePacked(
            // constructor
            bytes10(0x3d602d80600a3d3981f3),
            // proxy code
            bytes10(0x363d3d373d3d3d363d73),
            base,
            bytes15(0x5af43d82803e903d91602b57fd5bf3)
        );
        bytes32 salt = keccak256(bytes(name_));
        assembly {
            clone := create2(
                0, // no value
                add(createData, 0x20), // data
                mload(createData),
                salt
            )
        }
        // if CREATE2 fails for some reason, address(0) is returned
        if (clone == address(0)) revert NullDeploy();
    }
}
