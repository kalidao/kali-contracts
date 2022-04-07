// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Kali DAO tribute escrow interface
interface IKaliDAOtribute {
    enum ProposalType {
        MINT, 
        BURN, 
        CALL, 
        VPERIOD,
        GPERIOD, 
        QUORUM, 
        SUPERMAJORITY, 
        TYPE, 
        PAUSE, 
        EXTENSION,
        ESCAPE,
        DOCS
    }

    struct ProposalState {
        bool passed;
        bool processed;
    }

    function proposalStates(uint256 proposal) external view returns (ProposalState memory);

    function propose(
        ProposalType proposalType,
        string calldata description,
        address[] calldata accounts,
        uint256[] calldata amounts,
        bytes[] calldata payloads
    ) external payable returns (uint256 proposal);

    function cancelProposal(uint256 proposal) external payable;

    function processProposal(uint256 proposal) external payable returns (bool didProposalPass, bytes[] memory results);
}
