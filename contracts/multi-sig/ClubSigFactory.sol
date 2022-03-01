// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../libraries/ClonesWithImmutableArgs.sol';

/// @notice ClubSig Factory.
contract ClubSigFactory is Multicall {
    /// -----------------------------------------------------------------------
    /// Library usage
    /// -----------------------------------------------------------------------
    
    using ClonesWithImmutableArgs for address;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event SigDeployed(
        ClubSig indexed clubSig, 
        address[] signers, 
        uint256[] loots, 
        uint256 quorum, 
        bytes32 name, 
        bytes32 symbol, 
        bool paused
    );

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NullDeploy();

    /// -----------------------------------------------------------------------
    /// Immutable parameters
    /// -----------------------------------------------------------------------

    ClubSig internal immutable clubMaster;

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(ClubSig clubMaster_) {
        clubMaster = clubMaster_;
    }

    /// -----------------------------------------------------------------------
    /// Deployment
    /// -----------------------------------------------------------------------
    
    function deployClubSig(
        address[] calldata signers_, 
        uint256[] calldata tokenIds_,
        uint256[] calldata loots_, 
        uint256 quorum_,
        bytes32 name_,
        bytes32 symbol_,
        bool paused_
    ) public payable virtual returns (ClubSig clubSig) {
        bytes memory data = abi.encodePacked(name_, symbol_);

        clubSig = ClubSig(address(clubMaster).clone(data));

        clubSig.init(
            signers_, 
            tokenIds_,
            loots_, 
            quorum_,
            paused_
        );

        emit SigDeployed(clubSig, signers_, loots_, quorum_, name_, symbol_, paused_);
    }
}
