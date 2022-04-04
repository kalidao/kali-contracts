// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Kali DAO access manager interface
interface IKaliAccessManager {
    function balanceOf(address account, uint256 id) external returns (uint256);

    function joinList(
        address account,
        uint256 id,
        bytes32[] calldata merkleProof
    ) external;
}
