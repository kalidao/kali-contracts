// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {IKaliShareManager} from "../../interfaces/IKaliShareManager.sol";

import {ReentrancyGuard} from "../../utils/ReentrancyGuard.sol";

/// @notice Kali DAO share manager extension
contract KaliShareManager is ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ExtensionSet(
        address indexed dao,
        address[] managers,
        bool[] approvals
    );
    event ExtensionCalled(
        address indexed dao,
        address indexed manager,
        bytes[] updates
    );

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
        (address[] memory managers, bool[] memory approvals) = abi.decode(
            extensionData,
            (address[], bool[])
        );

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

    function callExtension(address dao, bytes[] calldata updates)
        external
        nonReentrant
    {
        if (!management[dao][msg.sender]) revert Forbidden();

        for (uint256 i; i < updates.length; ) {
            (
                address account,
                uint256 amount,
                bool mint
            ) = abi.decode(updates[i], (address, uint256, bool));

            if (mint) {
                IKaliShareManager(dao).mintShares(
                    account,
                    amount
                );
            } else {
                IKaliShareManager(dao).burnShares(
                    account,
                    amount
                );
            }
            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }

        emit ExtensionCalled(dao, msg.sender, updates);
    }
}
