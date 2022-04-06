// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Single owner access control contract
abstract contract KaliOwnable {
    event OwnershipTransferred(address indexed from, address indexed to);
    event ClaimTransferred(address indexed from, address indexed to);

    error NotOwner();
    error NotPendingOwner();

    address public owner;
    address public pendingOwner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function _init(address owner_) internal {
        owner = owner_;
        emit OwnershipTransferred(address(0), owner_);
    }

    function claimOwner() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();

        emit OwnershipTransferred(owner, msg.sender);

        owner = msg.sender;
        delete pendingOwner;
    }

    function transferOwner(address to, bool direct) external onlyOwner {
        if (direct) {
            owner = to;
            emit OwnershipTransferred(msg.sender, to);
        } else {
            pendingOwner = to;
            emit ClaimTransferred(msg.sender, to);
        }
    }
}
