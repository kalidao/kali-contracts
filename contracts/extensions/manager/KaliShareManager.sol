// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IKaliShareManager} from '../../interfaces/IKaliShareManager.sol';

import {ReentrancyGuard} from '../../utils/ReentrancyGuard.sol';

/// @notice Kali DAO share manager extension
contract KaliShareManager is ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ExtensionSet(address indexed dao, address[] managers, bool[] approvals);
    event ExtensionCalled(address indexed dao, address indexed manager, Update[] updates);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NoArrayParity();
    error Forbidden();

    /// -----------------------------------------------------------------------
    /// Mgmt Storage
    /// -----------------------------------------------------------------------

    mapping(address => mapping(address => bool)) public management;

    struct Update {
        address account;
        uint256 amount;
        bool mint;
    }

    /// -----------------------------------------------------------------------
    /// Mgmt Settings
    /// -----------------------------------------------------------------------

    function setExtension(bytes calldata extensionData) external {
        (
            address[] memory managers, 
            bool[] memory approvals
        ) 
            = abi.decode(extensionData, (address[], bool[]));
        
        if (managers.length != approvals.length) revert NoArrayParity();

        for (uint256 i; i < managers.length; ) {
            management[msg.sender][managers[i]] = approvals[i];
            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }

        emit ExtensionSet(msg.sender, managers, approvals);
    }

    /// -----------------------------------------------------------------------
    /// Mgmt Logic
    /// -----------------------------------------------------------------------

    function callExtension(address dao, Update[] calldata updates) external nonReentrant {
        if (!management[dao][msg.sender]) revert Forbidden();

        for (uint256 i; i < updates.length; ) {
            if (updates[i].mint) {
                IKaliShareManager(dao).mintShares(updates[i].account, updates[i].amount);
            } else {
                IKaliShareManager(dao).burnShares(updates[i].account, updates[i].amount);
            }
            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }

        emit ExtensionCalled(dao, msg.sender, updates);
    }
}
