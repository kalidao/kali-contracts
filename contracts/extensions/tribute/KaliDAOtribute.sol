// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../../libraries/SafeTransferLib.sol';
import './interfaces/IKaliDAOtribute.sol';
import '../../utils/Multicall.sol';
import '../../utils/ReentrancyGuard.sol';

/// @notice Tribute contract that escrows ETH or tokens for DAO proposals.
contract KaliDAOtribute is ReentrancyGuard {
    using SafeTransferLib for address;

    event NewTributeProposal(
        IKaliDAOtribute indexed dao,
        address indexed proposer, 
        uint256 indexed proposal, 
        address asset, 
        bool nft,
        uint256 value
    );

    event TributeProposalCancelled(IKaliDAOtribute indexed dao, uint256 indexed proposal);

    event TributeProposalReleased(IKaliDAOtribute indexed dao, uint256 indexed proposal);
    
    error NotProposer();

    error Sponsored(); 

    error NotProposal();

    error NotProcessed();

    mapping(IKaliDAOtribute => mapping(uint256 => Tribute)) public tributes;

    struct Tribute {
        IKaliDAOtribute dao;
        address proposer;
        address asset;
        bool nft;
        uint256 value;
    }

    function submitTributeProposal(
        IKaliDAOtribute dao,
        IKaliDAOtribute.ProposalType proposalType, 
        string memory description,
        address[] calldata accounts,
        uint256[] calldata amounts,
        bytes[] calldata payloads,
        bool nft,
        address asset, 
        uint256 value
    ) public payable nonReentrant virtual {
        // escrow tribute
        if (msg.value != 0) {
            asset = address(0);
            value = msg.value;
            if (nft) nft = false;
        } else {
            asset._safeTransferFrom(msg.sender, address(this), value);
        }

        uint256 proposal = dao.propose(
            proposalType,
            description,
            accounts,
            amounts,
            payloads
        );

        tributes[dao][proposal] = Tribute({
            dao: dao,
            proposer: msg.sender,
            asset: asset,
            nft: nft,
            value: value
        });

        emit NewTributeProposal(dao, msg.sender, proposal, asset, nft, value);
    }

    function cancelTributeProposal(IKaliDAOtribute dao, uint256 proposal) public nonReentrant virtual {
        Tribute storage trib = tributes[dao][proposal];

        if (msg.sender != trib.proposer) revert NotProposer();

        if (dao.proposals(proposal).creationTime != 0) revert Sponsored();

        dao.cancelProposal(proposal);

        // return tribute from escrow
        if (trib.asset == address(0)) {
            trib.proposer._safeTransferETH(trib.value);
        } else if (!trib.nft) {
            trib.asset._safeTransfer(trib.proposer, trib.value);
        } else {
            trib.asset._safeTransferFrom(address(this), trib.proposer, trib.value);
        }
        
        delete tributes[dao][proposal];

        emit TributeProposalCancelled(dao, proposal);
    }

    function releaseTributeProposal(IKaliDAOtribute dao, uint256 proposal) public nonReentrant virtual {
        Tribute memory trib = tributes[dao][proposal];

        if (address(trib.dao) == address(0)) revert NotProposal();
        
        delete tributes[dao][proposal];

        emit TributeProposalReleased(dao, proposal);

        if (dao.proposalStates(proposal).sponsoredProposal != 0) proposal = 
            dao.proposalStates(proposal).sponsoredProposal;

        IKaliDAOtribute.ProposalState memory prop = dao.proposalStates(proposal);

        if (!prop.processed) revert NotProcessed();

        // release tribute from escrow based on proposal outcome
        if (prop.passed) {
            if (trib.asset == address(0)) {
                address(trib.dao)._safeTransferETH(trib.value);
            } else if (!trib.nft) {
                trib.asset._safeTransfer(address(trib.dao), trib.value);
            } else {
                trib.asset._safeTransferFrom(address(this), address(trib.dao), trib.value);
            }
        } else {
            if (trib.asset == address(0)) {
                trib.proposer._safeTransferETH(trib.value);
            } else if (!trib.nft) {
                trib.asset._safeTransfer(trib.proposer, trib.value);
            } else {
                trib.asset._safeTransferFrom(address(this), trib.proposer, trib.value);
            }
        }
    }
}
