// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice Extension that brings information about a DAO's legal entity on chain.
contract KaliRegistry {

    event ExtensionSet(
        address indexed dao, 
        string legalName,
        string entityType,
        string jurisdiction,
        uint256 dateFormed
    );

    struct Entity {
        string legalName;
        string entityType;
        string jurisdiction;
        uint256 dateFormed;
    }

    mapping(address => Entity) public entities;

    function setExtension(bytes calldata extensionData) public {
        (string memory legalName, string memory entityType, string memory jurisdiction, uint256 dateFormed) 
            = abi.decode(extensionData, (string, string, string, uint256));

        entities[msg.sender] = Entity({
            legalName: legalName,
            entityType: entityType,
            jurisdiction: jurisdiction,
            dateFormed: dateFormed
        });

        emit ExtensionSet(msg.sender, legalName, entityType, jurisdiction, dateFormed);
    }
}
