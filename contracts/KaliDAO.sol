// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import './KaliDAOtoken.sol';
import './utils/Multicall.sol';
import './utils/NFThelper.sol';
import './utils/ReentrancyGuard.sol';
import './interfaces/IKaliDAOloot.sol';
import './interfaces/IKaliDAOextension.sol';

/// @notice Simple gas-optimized Kali DAO core module.
contract KaliDAO is KaliDAOtoken, Multicall, NFThelper, ReentrancyGuard {
    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
 
    event NewProposal(
        address indexed proposer,
        uint256 indexed proposal,
        ProposalType indexed proposalType,
        string description,
        address[] accounts,
        uint256[] amounts,
        bytes[] payloads
    );
    event ProposalCancelled(address indexed proposer, uint256 indexed proposal);
    event ProposalSponsored(address indexed sponsor, uint256 indexed proposal);
    event VoteCast(address indexed voter, uint256 indexed proposal, bool indexed approve);
    event ProposalProcessed(uint256 indexed proposal, bool indexed didProposalPass);
    event Ragequit(address indexed member, uint256 indexed votesToRedeem, uint256 indexed lootToRedeem);
 
    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
 
    error Initialized();
    error PeriodBounds();
    error QuorumMax();
    error SupermajorityBounds();
    error NullDeploy();
    error InitCallFail();
    error TypeBounds();
    error NotProposer();
    error Sponsored();
    error NotMember();
    error NotCurrentProposal();
    error AlreadyVoted();
    error NotVoteable();
    error VotingNotEnded();
    error PrevNotProcessed();
    error NotStarted();
    error TransferFailed();
    error NotExtension();
 
    /*///////////////////////////////////////////////////////////////
                            DAO STORAGE
    //////////////////////////////////////////////////////////////*/
 
    string public docs;
    uint256 private currentSponsoredProposal;
    uint256 public proposalCount;
    uint32 public votingPeriod;
    uint32 public gracePeriod;
    uint32 public redemptionStart;
    uint32 public quorum; // 1-100
    uint32 public supermajority; // 1-100
    IKaliDAOloot private immutable kaliDAOlootFactory;
    address public kaliDAOloot;
    bytes32 public constant VOTE_HASH =
        keccak256('SignVote(address signer,uint256 proposal,bool approve)');
  
    mapping(address => bool) public extensions;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => ProposalState) public proposalStates;
    mapping(ProposalType => VoteType) public proposalVoteTypes;
    mapping(uint256 => mapping(address => bool)) public voted;
    mapping(address => uint256) public lastYesVote;
 
    enum ProposalType {
        MINT, // add membership
        BURN, // revoke membership
        CALL, // call contracts
        VPERIOD, // set `votingPeriod`
        GPERIOD, // set `gracePeriod`
        RSTART, // set `redemptionStart`
        QUORUM, // set `quorum`
        SUPERMAJORITY, // set `supermajority`
        TYPE, // set `VoteType` to `ProposalType`
        PAUSE, // flip membership transferability
        EXTENSION, // flip `extensions` whitelisting
        ESCAPE, // delete pending proposal in case of revert
        DOCS // amend org docs
    }
 
    enum VoteType {
        SIMPLE_MAJORITY,
        SIMPLE_MAJORITY_QUORUM_REQUIRED,
        SUPERMAJORITY,
        SUPERMAJORITY_QUORUM_REQUIRED
    }
 
    struct Proposal {
        ProposalType proposalType;
        string description;
        address[] accounts; // member(s) being added/kicked; account(s) receiving payload
        uint256[] amounts; // value(s) to be minted/burned/spent; gov setting [0]
        bytes[] payloads; // data for CALL proposals
        uint256 prevProposal;
        uint96 yesVotes;
        uint96 noVotes;
        uint32 creationTime;
        address proposer;
    }
 
    struct ProposalState {
        bool passed;
        bool processed;
    }
 
    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IKaliDAOloot kaliDAOlootFactory_) {
        kaliDAOlootFactory = kaliDAOlootFactory_;
    }
 
    function init(
        string memory name_,
        string memory symbol_,
        string memory docs_,
        address[] memory extensions_,
        bytes[] memory extensionsData_,
        address[] calldata accounts_,
        uint256[] calldata votes_,
        uint256[] calldata loots_,
        uint32[20] memory govSettings_
    ) public payable nonReentrant virtual {
        if (extensions_.length != extensionsData_.length) revert NoArrayParity();
        if (votingPeriod != 0) revert Initialized();
        if (govSettings_[2] == 0 || govSettings_[1] > 365 days) revert PeriodBounds();
        if (govSettings_[3] > 365 days) revert PeriodBounds();
        if (govSettings_[5] > 100) revert QuorumMax();
        if (govSettings_[6] <= 51 || govSettings_[4] > 100) revert SupermajorityBounds();
 
        bool votesPaused_;
        if (govSettings_[0] != 0) votesPaused_ = true;
 
        KaliDAOtoken._init(name_, symbol_, votesPaused_, accounts_, votes_);

        bool lootsPaused_;
        if (govSettings_[1] != 0) lootsPaused_ = true;

        kaliDAOloot = kaliDAOlootFactory.deployKaliDAOloot(
            name_, 
            symbol_, 
            lootsPaused_,
            accounts_,
            loots_,
            address(this)
        );
        if (extensions_.length != 0) {
            // cannot realistically overflow on human timescales
            unchecked {
                for (uint256 i; i < extensions_.length; i++) {
                    extensions[extensions_[i]] = true;
                    if (extensionsData_[i].length > 1) {
                        (bool success, ) = extensions_[i].call(extensionsData_[i]);

                        if (!success) revert InitCallFail();
                    }
                }
            }
        }
        docs = docs_;
        votingPeriod = govSettings_[2];
        gracePeriod = govSettings_[3];
        redemptionStart = govSettings_[4];
        quorum = govSettings_[5];
        supermajority = govSettings_[6];
 
        // set initial vote types
        proposalVoteTypes[ProposalType.MINT] = VoteType(govSettings_[7]);
        proposalVoteTypes[ProposalType.BURN] = VoteType(govSettings_[8]);
        proposalVoteTypes[ProposalType.CALL] = VoteType(govSettings_[9]);
        proposalVoteTypes[ProposalType.VPERIOD] = VoteType(govSettings_[10]);
        proposalVoteTypes[ProposalType.GPERIOD] = VoteType(govSettings_[11]);
        proposalVoteTypes[ProposalType.RSTART] = VoteType(govSettings_[12]);
        proposalVoteTypes[ProposalType.QUORUM] = VoteType(govSettings_[13]);
        proposalVoteTypes[ProposalType.SUPERMAJORITY] = VoteType(govSettings_[14]);
        proposalVoteTypes[ProposalType.TYPE] = VoteType(govSettings_[15]);
        proposalVoteTypes[ProposalType.PAUSE] = VoteType(govSettings_[16]);
        proposalVoteTypes[ProposalType.EXTENSION] = VoteType(govSettings_[17]);
        proposalVoteTypes[ProposalType.ESCAPE] = VoteType(govSettings_[18]);
        proposalVoteTypes[ProposalType.DOCS] = VoteType(govSettings_[19]);
    }

    /*///////////////////////////////////////////////////////////////
                            PROPOSAL LOGIC
    //////////////////////////////////////////////////////////////*/
 
    function getProposalArrays(uint256 proposal) public view virtual returns (
        address[] memory accounts,
        uint256[] memory amounts,
        bytes[] memory payloads
    ) {
        Proposal storage prop = proposals[proposal];
        (accounts, amounts, payloads) = (prop.accounts, prop.amounts, prop.payloads);
    }
 
    function propose(
        ProposalType proposalType,
        string calldata description,
        address[] calldata accounts,
        uint256[] calldata amounts,
        bytes[] calldata payloads
    ) public nonReentrant virtual returns (uint256 proposal) {
        if (accounts.length != amounts.length || amounts.length != payloads.length) revert NoArrayParity();
        if (proposalType == ProposalType.VPERIOD) if (amounts[0] == 0 || amounts[0] > 365 days) revert PeriodBounds();
        if (proposalType == ProposalType.GPERIOD) if (amounts[0] == 0 || amounts[0] > 365 days) revert PeriodBounds();
        if (proposalType == ProposalType.QUORUM) if (amounts[0] > 100) revert QuorumMax();
        if (proposalType == ProposalType.SUPERMAJORITY) if (amounts[0] <= 51 || amounts[0] > 100) revert SupermajorityBounds();
        if (proposalType == ProposalType.TYPE) if (amounts[0] > 11 || amounts[1] > 3 || amounts.length != 2) revert TypeBounds();
 
        bool selfSponsor;
 
        // if member or extension is making proposal, include sponsorship
        if (balanceOf[msg.sender] != 0 || extensions[msg.sender]) selfSponsor = true;
 
        // cannot realistically overflow on human timescales
        unchecked {
            proposalCount++;
        }
 
        proposal = proposalCount;
 
        proposals[proposal] = Proposal({
            proposalType: proposalType,
            description: description,
            accounts: accounts,
            amounts: amounts,
            payloads: payloads,
            prevProposal: selfSponsor ? currentSponsoredProposal : 0,
            yesVotes: 0,
            noVotes: 0,
            creationTime: selfSponsor ? _safeCastTo32(block.timestamp) : 0,
            proposer: msg.sender
        });
 
        if (selfSponsor) currentSponsoredProposal = proposal;
 
        emit NewProposal(msg.sender, proposal, proposalType, description, accounts, amounts, payloads);
    }
 
    function cancelProposal(uint256 proposal) public nonReentrant virtual {
        Proposal storage prop = proposals[proposal];
 
        if (msg.sender != prop.proposer) revert NotProposer();
        if (prop.creationTime != 0) revert Sponsored();
 
        delete proposals[proposal];
 
        emit ProposalCancelled(msg.sender, proposal);
    }
 
    function sponsorProposal(uint256 proposal) public nonReentrant virtual {
        Proposal storage prop = proposals[proposal];
 
        if (balanceOf[msg.sender] == 0) revert NotMember();
        if (prop.proposer == address(0)) revert NotCurrentProposal();
        if (prop.creationTime != 0) revert Sponsored();
 
        prop.prevProposal = currentSponsoredProposal;
        currentSponsoredProposal = proposal;
        prop.creationTime = _safeCastTo32(block.timestamp);
 
        emit ProposalSponsored(msg.sender, proposal);
    }
 
    function vote(uint256 proposal, bool approve) public nonReentrant virtual {
        _vote(msg.sender, proposal, approve);
    }
   
    function voteBySig(
        address signer,
        uint256 proposal,
        bool approve,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant virtual {
        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            VOTE_HASH,
                            signer,
                            proposal,
                            approve
                        )
                    )
                )
            ); 
        address recoveredAddress = ecrecover(digest, v, r, s);
 
        if (recoveredAddress == address(0) || recoveredAddress != signer) revert InvalidSignature();
       
        _vote(signer, proposal, approve);
    }
   
    function _vote(
        address signer,
        uint256 proposal,
        bool approve
    ) internal virtual {
        Proposal storage prop = proposals[proposal];
 
        if (balanceOf[signer] == 0) revert NotMember();
        if (voted[proposal][signer]) revert AlreadyVoted();
        // this is safe from overflow because `votingPeriod` is capped so it will not combine
        // with unix time to exceed the max uint256 value
        unchecked {
            if (block.timestamp > prop.creationTime + votingPeriod) revert NotVoteable();
        }
        uint96 weight = getPriorVotes(signer, prop.creationTime);
        // this is safe from overflow because `yesVotes` and `noVotes` are capped by `totalSupply`
        // which is checked for overflow in `KaliDAOtoken` contract
        unchecked {
            if (approve) {
                prop.yesVotes += weight;
                lastYesVote[signer] = proposal;
            } else {
                prop.noVotes += weight;
            }
        }
        voted[proposal][signer] = true;
       
        emit VoteCast(signer, proposal, approve);
    }
 
    function processProposal(uint256 proposal) public nonReentrant virtual returns (
        bool didProposalPass, bytes[] memory results
    ) {
        Proposal storage prop = proposals[proposal];
        VoteType voteType = proposalVoteTypes[prop.proposalType];
 
        if (prop.creationTime == 0) revert NotCurrentProposal();
       
        // this is safe from overflow because `votingPeriod` and `gracePeriod` are capped so they will not combine
        // with unix time to exceed the max uint256 value
        unchecked {
            if (block.timestamp <= prop.creationTime + votingPeriod + gracePeriod) revert VotingNotEnded();
        }
 
        // skip previous proposal processing requirement in case of escape hatch
        if (prop.proposalType != ProposalType.ESCAPE)
            if (proposals[prop.prevProposal].creationTime != 0) revert PrevNotProcessed();
 
        didProposalPass = _countVotes(voteType, prop.yesVotes, prop.noVotes);
       
        if (didProposalPass) {
            // cannot realistically overflow on human timescales
            unchecked {
                if (prop.proposalType == ProposalType.MINT)
                    for (uint256 i; i < prop.accounts.length; i++) {
                        _mint(prop.accounts[i], prop.amounts[i]);
                    }
                if (prop.proposalType == ProposalType.BURN)
                    for (uint256 i; i < prop.accounts.length; i++) {
                        _burn(prop.accounts[i], prop.amounts[i]);
                    }
                if (prop.proposalType == ProposalType.CALL)
                    for (uint256 i; i < prop.accounts.length; i++) {
                        results = new bytes[](prop.accounts.length);
                       
                        (, bytes memory result) = prop.accounts[i].call{value: prop.amounts[i]}
                            (prop.payloads[i]);
                       
                        results[i] = result;
                    }
                // governance settings
                if (prop.proposalType == ProposalType.VPERIOD)
                    if (prop.amounts[0] != 0) votingPeriod = uint32(prop.amounts[0]);
               
                if (prop.proposalType == ProposalType.GPERIOD)
                    if (prop.amounts[0] != 0) gracePeriod = uint32(prop.amounts[0]);
                
                if (prop.proposalType == ProposalType.RSTART)
                    if (prop.amounts[0] != 0) redemptionStart = uint32(prop.amounts[0]);
               
                if (prop.proposalType == ProposalType.QUORUM)
                    if (prop.amounts[0] != 0) quorum = uint32(prop.amounts[0]);
               
                if (prop.proposalType == ProposalType.SUPERMAJORITY)
                    if (prop.amounts[0] != 0) supermajority = uint32(prop.amounts[0]);
               
                if (prop.proposalType == ProposalType.TYPE)
                    proposalVoteTypes[ProposalType(prop.amounts[0])] = VoteType(prop.amounts[1]);
               
                if (prop.proposalType == ProposalType.PAUSE)
                    _flipPause();
               
                if (prop.proposalType == ProposalType.EXTENSION) 
                    for (uint256 i; i < prop.accounts.length; i++) {
                        if (prop.amounts[i] != 0) 
                            extensions[prop.accounts[i]] = !extensions[prop.accounts[i]];
                    
                        if (prop.payloads[i].length > 1) IKaliDAOextension(prop.accounts[i])
                            .setExtension(prop.payloads[i]);
                    }
               
                if (prop.proposalType == ProposalType.ESCAPE)
                    delete proposals[prop.amounts[0]];
 
                if (prop.proposalType == ProposalType.DOCS)
                    docs = prop.description;
               
                proposalStates[proposal].passed = true;
            }
        }
        delete proposals[proposal];
        proposalStates[proposal].processed = true;
 
        emit ProposalProcessed(proposal, didProposalPass);
    }
 
    function _countVotes(
        VoteType voteType,
        uint256 yesVotes,
        uint256 noVotes
    ) internal view virtual returns (bool didProposalPass) {
        // fail proposal if no participation
        if (yesVotes == 0 && noVotes == 0) return false;
        // rule out any failed quorums
        if (voteType == VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED || voteType == VoteType.SUPERMAJORITY_QUORUM_REQUIRED) {
            uint256 minVotes = (totalSupply * quorum) / 100;
            // this is safe from overflow because `yesVotes` and `noVotes`
            // supply are checked in `KaliDAOtoken` contract
            unchecked {
                uint256 votes = yesVotes + noVotes;
                if (votes < minVotes) return false;
            }
        }
        // simple majority check
        if (voteType == VoteType.SIMPLE_MAJORITY || voteType == VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED) {
            if (yesVotes > noVotes) return true;
        // supermajority check
        } else {
            // example: 7 yes, 2 no, supermajority = 66
            // ((7+2) * 66) / 100 = 5.94; 7 yes will pass
            uint256 minYes = ((yesVotes + noVotes) * supermajority) / 100;
            if (yesVotes >= minYes) return true;
        }
    }

    /*///////////////////////////////////////////////////////////////
                            BANKING
    //////////////////////////////////////////////////////////////*/

    function ragequit(
        address[] calldata tokensToClaim, 
        uint256 votesToRedeem,
        uint256 lootToRedeem
    ) public nonReentrant virtual {
        if (block.timestamp < redemptionStart) revert NotStarted();

        for (uint256 i; i < tokensToClaim.length;) {
            // calculate fair share of given token for redemption
            uint256 amountToRedeem = (votesToRedeem + lootToRedeem) * 
                IKaliDAOloot(tokensToClaim[i]).balanceOf(address(this)) / 
                (totalSupply + IKaliDAOloot(kaliDAOloot).totalSupply());
            // transfer to redeemer
            if (amountToRedeem != 0) {
                _safeTransfer(
                    tokensToClaim[i],
                    msg.sender, 
                    amountToRedeem
                );
            }
            unchecked {
                i++;
            }
        }
        if (votesToRedeem != 0) {
            _burn(msg.sender, votesToRedeem);
        }
        if (lootToRedeem != 0) {
            IKaliDAOloot(kaliDAOloot).ownerBurn(msg.sender, lootToRedeem);
        }

        emit Ragequit(msg.sender, votesToRedeem, lootToRedeem);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 amount
    ) internal virtual {
        bool callStatus;

        assembly {
            // get a pointer to some free memory
            let freeMemoryPointer := mload(0x40)
            // write the abi-encoded calldata to memory piece by piece:
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) // begin with the function selector
            mstore(add(freeMemoryPointer, 4), and(to, 0xffffffffffffffffffffffffffffffffffffffff)) // mask and append the "to" argument
            mstore(add(freeMemoryPointer, 36), amount) // finally append the "amount" argument - no mask as it's a full 32 byte value
            // call the token and store if it succeeded or not
            // we use 68 because the calldata length is 4 + 32 * 2
            callStatus := call(gas(), token, 0, freeMemoryPointer, 68, 0, 0)
        }

        if (!_didLastOptionalReturnCallSucceed(callStatus)) revert TransferFailed();
    }

    function _didLastOptionalReturnCallSucceed(bool callStatus) internal pure virtual returns (bool success) {
        assembly {
            // get how many bytes the call returned
            let returnDataSize := returndatasize()
            // if the call reverted:
            if iszero(callStatus) {
                // copy the revert message into memory
                returndatacopy(0, 0, returnDataSize)

                // revert with the same message
                revert(0, returnDataSize)
            }
            switch returnDataSize

            case 32 {
                // copy the return data into memory
                returndatacopy(0, 0, returnDataSize)
                // set success to whether it returned true
                success := iszero(iszero(mload(0)))
            }
            case 0 {
                // there was no return data
                success := 1
            }
            default {
                // it returned some malformed input
                success := 0
            }
        }
    }
   
    /*///////////////////////////////////////////////////////////////
                            EXTENSIONS
    //////////////////////////////////////////////////////////////*/
 
    receive() external payable virtual {}
 
    modifier onlyExtension {
        if (!extensions[msg.sender]) revert NotExtension();
        _;
    }
 
    function callExtension(
        address extension,
        uint256 amount,
        bytes calldata extensionData
    ) public payable nonReentrant virtual returns (bool mint, uint256 amountOut) {
        if (!extensions[extension]) revert NotExtension();
       
        (mint, amountOut) = IKaliDAOextension(extension).callExtension{value: msg.value}
            (msg.sender, amount, extensionData);

        if (mint) {
            if (amountOut != 0) _mint(msg.sender, amountOut);
        } else {
            if (amountOut != 0) _burn(msg.sender, amount);
        }
    }
 
    function mintShares(address to, uint256 amount) public onlyExtension virtual {
        _mint(to, amount);
    }
 
    function burnShares(address from, uint256 amount) public onlyExtension virtual {
        _burn(from, amount);
    }
 
    function updateGovernance(
        uint32 votingPeriod_,
        uint32 gracePeriod_,
        uint32 quorum_,
        uint32 supermajority_,
        bool flipPause
    ) public onlyExtension virtual {
        if (votingPeriod_ != 0 && votingPeriod_ <= 365 days) votingPeriod = votingPeriod_;
        if (gracePeriod_ <= 365 days) gracePeriod = gracePeriod_;
        if (quorum_ <= 100) quorum = quorum_;
        if (supermajority_ > 51 && supermajority_ <= 100) supermajority = supermajority_;
        if (flipPause) _flipPause();
    }
 
    function updateExtension(address extension) public onlyExtension virtual {
        extensions[extension] = !extensions[extension];
    }
 
    function escapeProposal(uint256 proposal) public onlyExtension virtual {
        delete proposals[proposal];
    }
}
