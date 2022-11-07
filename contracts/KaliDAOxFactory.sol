// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice A generic interface for a contract which properly accepts ERC-1155 tokens.
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external payable virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external payable virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

/// @notice Minimalist and gas efficient standard ERC-1155 implementation with supply tracking.
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155 {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event URI(string value, uint256 indexed id);

    /// -----------------------------------------------------------------------
    /// ERC-1155 STORAGE
    /// -----------------------------------------------------------------------

    mapping(uint256 => uint256) public totalSupply;

    mapping(address => mapping(uint256 => uint256)) public balanceOf;

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// -----------------------------------------------------------------------
    /// METADATA LOGIC
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view virtual returns (string memory);

    /// -----------------------------------------------------------------------
    /// ERC-165 LOGIC
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        returns (bool)
    {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165 Interface ID for ERC-165
            interfaceId == 0xd9b67a26 || // ERC-165 Interface ID for ERC-1155
            interfaceId == 0x0e89341c; // ERC-165 Interface ID for ERC1155MetadataURI
    }

    /// -----------------------------------------------------------------------
    /// ERC-1155 LOGIC
    /// -----------------------------------------------------------------------

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        require(owners.length == ids.length, "LENGTH_MISMATCH");

        balances = new uint256[](owners.length);

        // Unchecked because the only math done is incrementing
        // the array index counter which cannot possibly overflow.
        unchecked {
            for (uint256 i; i < owners.length; ++i) {
                balances[i] = balanceOf[owners[i]][ids[i]];
            }
        }
    }

    function setApprovalForAll(address operator, bool approved)
        public
        payable
        virtual
    {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public payable virtual {
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        balanceOf[from][id] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit TransferSingle(msg.sender, from, to, id, amount);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    from,
                    id,
                    amount,
                    data
                ) == ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public payable virtual {
        require(ids.length == amounts.length, "LENGTH_MISMATCH");

        require(
            msg.sender == from || isApprovedForAll[from][msg.sender],
            "NOT_AUTHORIZED"
        );

        // Storing these outside the loop saves ~15 gas per iteration.
        uint256 id;
        uint256 amount;

        for (uint256 i; i < ids.length; ) {
            id = ids[i];
            amount = amounts[i];

            balanceOf[from][id] -= amount;

            // Cannot overflow because the sum of all user
            // balances can't exceed the max uint256 value,
            // and an array can't have a total length
            // larger than the max uint256 value.
            unchecked {
                balanceOf[to][id] += amount;

                ++i;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155BatchReceived(
                    msg.sender,
                    from,
                    ids,
                    amounts,
                    data
                ) == ERC1155TokenReceiver.onERC1155BatchReceived.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    /// -----------------------------------------------------------------------
    /// INTERNAL MINT/BURN LOGIC
    /// -----------------------------------------------------------------------

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) internal virtual {
        totalSupply[id] += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to][id] += amount;
        }

        emit TransferSingle(msg.sender, address(0), to, id, amount);

        if (to.code.length != 0) {
            require(
                ERC1155TokenReceiver(to).onERC1155Received(
                    msg.sender,
                    address(0),
                    id,
                    amount,
                    data
                ) == ERC1155TokenReceiver.onERC1155Received.selector,
                "UNSAFE_RECIPIENT"
            );
        } else require(to != address(0), "INVALID_RECIPIENT");
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
        balanceOf[from][id] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply[id] -= amount;
        }

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }
}

/// @notice Compound-like voting extension for ERC-1155.
/// @author KaliCo LLC
/// @custom:coauthor Seed Club Ventures (@seedclubvc)
abstract contract ERC1155Votes is ERC1155 {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate,
        uint256 id
    );

    event DelegateVotesChanged(
        address indexed delegate,
        uint256 indexed id,
        uint256 previousBalance,
        uint256 newBalance
    );

    /// -----------------------------------------------------------------------
    /// VOTING STORAGE
    /// -----------------------------------------------------------------------

    mapping(address => mapping(uint256 => address)) internal _delegates;

    mapping(address => mapping(uint256 => uint256)) public numCheckpoints;

    mapping(address => mapping(uint256 => mapping(uint256 => Checkpoint)))
        public checkpoints;

    struct Checkpoint {
        uint40 fromTimestamp;
        uint216 votes;
    }

    /// -----------------------------------------------------------------------
    /// DELEGATION LOGIC
    /// -----------------------------------------------------------------------

    function delegates(address account, uint256 id)
        public
        view
        virtual
        returns (address)
    {
        address current = _delegates[account][id];

        return current == address(0) ? account : current;
    }

    function getCurrentVotes(address account, uint256 id)
        public
        view
        virtual
        returns (uint256)
    {
        // Won't underflow because decrement only occurs if positive `nCheckpoints`.
        unchecked {
            uint256 nCheckpoints = numCheckpoints[account][id];

            return
                nCheckpoints != 0
                    ? checkpoints[account][id][nCheckpoints - 1].votes
                    : 0;
        }
    }

    function getPriorVotes(
        address account,
        uint256 id,
        uint256 timestamp
    ) public view virtual returns (uint256) {
        require(block.timestamp > timestamp, "UNDETERMINED");

        uint256 nCheckpoints = numCheckpoints[account][id];

        if (nCheckpoints == 0) return 0;

        // Won't underflow because decrement only occurs if positive `nCheckpoints`.
        unchecked {
            if (
                checkpoints[account][id][nCheckpoints - 1].fromTimestamp <=
                timestamp
            ) return checkpoints[account][id][nCheckpoints - 1].votes;

            if (checkpoints[account][id][0].fromTimestamp > timestamp) return 0;

            uint256 lower;

            uint256 upper = nCheckpoints - 1;

            while (upper > lower) {
                uint256 center = upper - (upper - lower) / 2;

                Checkpoint memory cp = checkpoints[account][id][center];

                if (cp.fromTimestamp == timestamp) {
                    return cp.votes;
                } else if (cp.fromTimestamp < timestamp) {
                    lower = center;
                } else {
                    upper = center - 1;
                }
            }

            return checkpoints[account][id][lower].votes;
        }
    }

    function delegate(address delegatee, uint256 id) public payable virtual {
        address currentDelegate = delegates(msg.sender, id);

        _delegates[msg.sender][id] = delegatee;

        emit DelegateChanged(msg.sender, currentDelegate, delegatee, id);

        _moveDelegates(
            currentDelegate,
            delegatee,
            id,
            balanceOf[msg.sender][id]
        );
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 id,
        uint256 amount
    ) internal virtual {
        if (srcRep != dstRep && amount != 0) {
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep][id];

                uint256 srcRepOld;

                // Won't underflow because decrement only occurs if positive `srcRepNum`.
                unchecked {
                    srcRepOld = srcRepNum != 0
                        ? checkpoints[srcRep][id][srcRepNum - 1].votes
                        : 0;
                }

                _writeCheckpoint(
                    srcRep,
                    id,
                    srcRepNum,
                    srcRepOld,
                    srcRepOld - amount
                );
            }

            if (dstRep != address(0)) {
                uint256 dstRepNum = numCheckpoints[dstRep][id];

                uint256 dstRepOld;

                // Won't underflow because decrement only occurs if positive `dstRepNum`.
                unchecked {
                    dstRepOld = dstRepNum != 0
                        ? checkpoints[dstRep][id][dstRepNum - 1].votes
                        : 0;
                }

                _writeCheckpoint(
                    dstRep,
                    id,
                    dstRepNum,
                    dstRepOld,
                    dstRepOld + amount
                );
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 id,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal virtual {
        // Won't underflow because decrement only occurs if positive `nCheckpoints`.
        unchecked {
            if (
                nCheckpoints != 0 &&
                checkpoints[delegatee][id][nCheckpoints - 1].fromTimestamp ==
                block.timestamp
            ) {
                checkpoints[delegatee][id][nCheckpoints - 1]
                    .votes = _safeCastTo216(newVotes);
            } else {
                checkpoints[delegatee][id][nCheckpoints] = Checkpoint(
                    _safeCastTo40(block.timestamp),
                    _safeCastTo216(newVotes)
                );

                // Won't realistically overflow.
                ++numCheckpoints[delegatee][id];
            }
        }

        emit DelegateVotesChanged(delegatee, id, oldVotes, newVotes);
    }

    function _safeCastTo40(uint256 x) internal pure virtual returns (uint40 y) {
        require(x < 1 << 40);

        y = uint40(x);
    }

    function _safeCastTo216(uint256 x)
        internal
        pure
        virtual
        returns (uint216 y)
    {
        require(x < 1 << 216);

        y = uint216(x);
    }
}

/// @notice Contract that enables a single call to call multiple methods on itself.
/// @author Modified from Solady (https://github.com/Vectorized/solady/blob/main/src/utils/Multicallable.sol)
abstract contract Multicallable {
    function multicall(bytes[] calldata data) public payable virtual returns (bytes[] memory results) {
        assembly {
            if data.length {
                results := mload(0x40) // point `results` to start of free memory
                mstore(results, data.length) // store `data.length` into `results`
                results := add(results, 0x20)

                // `shl` 5 is equivalent to multiplying by 0x20
                let end := shl(5, data.length)
                // copy the offsets from calldata into memory
                calldatacopy(results, data.offset, end)
                // pointer to the top of the memory (i.e., start of the free memory)
                let memPtr := add(results, end)
                end := add(results, end)

                for {} 1 {} {
                    // the offset of the current bytes in the calldata
                    let o := add(data.offset, mload(results))
                    
                    // copy the current bytes from calldata to the memory
                    calldatacopy(
                        memPtr,
                        add(o, 0x20), // the offset of the current bytes' bytes
                        calldataload(o) // the length of the current bytes
                    )
                    
                    if iszero(delegatecall(gas(), address(), memPtr, calldataload(o), 0x00, 0x00)) {
                        // bubble up the revert if the delegatecall reverts
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    
                    // append the current `memPtr` into `results`
                    mstore(results, memPtr)
                    results := add(results, 0x20)
                    // append the `returndatasize()`, and the return data
                    mstore(memPtr, returndatasize())
                    returndatacopy(add(memPtr, 0x20), 0x00, returndatasize())
                    // advance the `memPtr` by `returndatasize() + 0x20`,
                    // rounded up to the next multiple of 32
                    memPtr := and(add(add(memPtr, returndatasize()), 0x3f), 0xffffffffffffffe0)

                    if iszero(lt(results, end)) { break }
                }
                
                // restore `results` and allocate memory for it
                results := mload(0x40)
                mstore(0x40, memPtr)
            }
        }
    }
}

/// @notice Contract that enables NFT receipt.
abstract contract NFTreceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return NFTreceiver.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return NFTreceiver.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return NFTreceiver.onERC1155BatchReceived.selector;
    }
}

/// @notice Gas-optimized reentrancy protection.
/// @author Modified from OpenZeppelin 
/// (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol)
/// License-Identifier: MIT
abstract contract ReentrancyGuard {
    error Reentrancy();

    uint256 private constant NOT_ENTERED = 1;

    uint256 private constant ENTERED = 2;

    uint256 private status = NOT_ENTERED;

    modifier nonReentrant() {
        if (status == ENTERED) revert Reentrancy();

        status = ENTERED;

        _;

        status = NOT_ENTERED;
    }
}

/// @notice Kali DAO extension interface.
interface IKaliDAOxExtension {
    function setExtension(bytes calldata extensionData) external payable;
}

/// @notice Simple gas-optimized Kali DAO core module.
contract KaliDAOx is ERC1155Votes, Multicallable, NFTreceiver, ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event NewProposal(
        address indexed proposer, 
        uint256 proposal, 
        ProposalType proposalType, 
        bytes32 description, 
        address[] accounts, 
        uint256[] amounts, 
        bytes[] payloads,
        uint32 creationTime,
        bool selfSponsor
    );

    event ProposalCancelled(address indexed proposer, uint256 proposal);

    event ProposalSponsored(address indexed sponsor, uint256 proposal);
    
    event VoteCast(
        address indexed voter, 
        uint256 proposal, 
        bool approve,
        uint96 weight
    );

    event ProposalProcessed(uint256 proposal, bool didProposalPass);

    event ExtensionSet(address extension, bool set);

    event URIset(string daoURI);

    event GovSettingsUpdated(
        uint64 votingPeriod, 
        uint64 gracePeriod, 
        uint64 quorum, 
        uint64 supermajority
    );

    /// -----------------------------------------------------------------------
    /// ERRORS
    /// -----------------------------------------------------------------------

    error Initialized();

    error PeriodBounds();

    error QuorumMax();

    error SupermajorityBounds();

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

    error NotExtension();

    /// -----------------------------------------------------------------------
    /// DAO STORAGE/LOGIC
    /// -----------------------------------------------------------------------

    string public daoURI;

    uint256 internal currentSponsoredProposal;
    
    uint256 public proposalCount;

    uint64 public votingPeriod;

    uint64 public gracePeriod;

    uint64 public quorum; // 1-100

    uint64 public supermajority; // 1-100
    
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
        uint256 prevProposal;
        bytes32 proposalHash;
        address proposer;
        uint32 creationTime;
        uint96 yesVotes;
        uint96 noVotes;
    }

    struct ProposalState {
        bool passed;
        bool processed;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        returns (bool)
    {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165 Interface ID for ERC-165
            interfaceId == 0x150b7a02 || // ERC-165 Interface ID for ERC721TokenReceiver
            interfaceId == 0x4e2312e0; // ERC-165 Interface ID for ERC1155TokenReceiver
    }

    /// -----------------------------------------------------------------------
    /// INITIALIZER
    /// -----------------------------------------------------------------------

    function init(
        string calldata daoURI_,
        bool paused_,
        address[] calldata extensions_,
        bytes[] calldata extensionsData_,
        address[] calldata voters_,
        uint256[] calldata shares_,
        uint64[16] calldata govSettings_
    ) public payable virtual {
        if (extensions_.length != extensionsData_.length) revert NoArrayParity();

        if (votingPeriod != 0) revert Initialized();

        if (govSettings_[0] == 0) revert PeriodBounds(); 
        
        if (govSettings_[0] > 365 days) revert PeriodBounds();

        if (govSettings_[1] > 365 days) revert PeriodBounds();

        if (govSettings_[2] > 100) revert QuorumMax();

        if (govSettings_[3] <= 51) revert SupermajorityBounds();
        
        if (govSettings_[3] > 100) revert SupermajorityBounds();

        KaliDAOxToken._init(
            paused_, 
            voters_, 
            shares_
        );

        if (extensions_.length != 0) {
            // cannot realistically overflow on human timescales
            unchecked {
                for (uint256 i; i < extensions_.length; i++) {
                    extensions[extensions_[i]] = true;

                    if (extensionsData_[i].length > 9) {
                        (bool success, ) = extensions_[i].call(extensionsData_[i]);

                        if (!success) revert InitCallFail();
                    }
                }
            }
        }

        daoURI = daoURI_;
        
        votingPeriod = govSettings_[0];

        gracePeriod = govSettings_[1];
        
        quorum = govSettings_[2];
        
        supermajority = govSettings_[3];

        // set initial vote types
        proposalVoteTypes[ProposalType.MINT] = VoteType(govSettings_[4]);

        proposalVoteTypes[ProposalType.BURN] = VoteType(govSettings_[5]);

        proposalVoteTypes[ProposalType.CALL] = VoteType(govSettings_[6]);

        proposalVoteTypes[ProposalType.VPERIOD] = VoteType(govSettings_[7]);

        proposalVoteTypes[ProposalType.GPERIOD] = VoteType(govSettings_[8]);
        
        proposalVoteTypes[ProposalType.QUORUM] = VoteType(govSettings_[9]);
        
        proposalVoteTypes[ProposalType.SUPERMAJORITY] = VoteType(govSettings_[10]);

        proposalVoteTypes[ProposalType.TYPE] = VoteType(govSettings_[11]);
        
        proposalVoteTypes[ProposalType.PAUSE] = VoteType(govSettings_[12]);
        
        proposalVoteTypes[ProposalType.EXTENSION] = VoteType(govSettings_[13]);

        proposalVoteTypes[ProposalType.ESCAPE] = VoteType(govSettings_[14]);

        proposalVoteTypes[ProposalType.DOCS] = VoteType(govSettings_[15]);
    }

    /// -----------------------------------------------------------------------
    /// PROPOSAL LOGIC
    /// -----------------------------------------------------------------------

    function propose(
        ProposalType proposalType,
        bytes32 description,
        address[] calldata accounts, // member(s) being added/kicked; account(s) receiving payload
        uint256[] calldata amounts, // value(s) to be minted/burned/spent; gov setting [0]
        bytes[] calldata payloads // data for CALL proposals
    ) public payable virtual returns (uint256 proposal) {
        if (accounts.length != amounts.length) revert NoArrayParity();

        if (amounts.length != payloads.length) revert NoArrayParity();
        
        if (proposalType == ProposalType.VPERIOD) if (amounts[0] == 0 || amounts[0] > 365 days) revert PeriodBounds();

        if (proposalType == ProposalType.GPERIOD) if (amounts[0] > 365 days) revert PeriodBounds();
        
        if (proposalType == ProposalType.QUORUM) if (amounts[0] > 100) revert QuorumMax();
        
        if (proposalType == ProposalType.SUPERMAJORITY) if (amounts[0] <= 51 || amounts[0] > 100) revert SupermajorityBounds();

        if (proposalType == ProposalType.TYPE) if (amounts[0] > 11 || amounts[1] > 3 || amounts.length != 2) revert TypeBounds();

        bool selfSponsor;

        // if member or extension is making proposal, include sponsorship
        if (balanceOf[msg.sender] != 0 || extensions[msg.sender]) selfSponsor = true;

        // cannot realistically overflow on human timescales
        unchecked {
            proposal = ++proposalCount;
        }

        bytes32 proposalHash = keccak256(
            abi.encode(
                proposalType,
                description,
                accounts,
                amounts,
                payloads
            )
        );

        uint32 creationTime = selfSponsor ? _safeCastTo32(block.timestamp) : 0;

        proposals[proposal] = Proposal({
            prevProposal: selfSponsor ? currentSponsoredProposal : 0,
            proposalHash: proposalHash,
            proposer: msg.sender,
            creationTime: creationTime,
            yesVotes: 0,
            noVotes: 0
        });

        if (selfSponsor) currentSponsoredProposal = proposal;

        emit NewProposal(
            msg.sender, 
            proposal, 
            proposalType, 
            description,
            accounts, 
            amounts, 
            payloads,
            creationTime,
            selfSponsor
        );
    }

    function cancelProposal(uint256 proposal) public payable virtual {
        Proposal storage prop = proposals[proposal];

        if (msg.sender != prop.proposer) revert NotProposer();

        if (prop.creationTime != 0) revert Sponsored();

        delete proposals[proposal];

        emit ProposalCancelled(msg.sender, proposal);
    }

    function sponsorProposal(uint256 proposal) public payable virtual {
        Proposal storage prop = proposals[proposal];

        if (balanceOf[msg.sender] == 0) revert NotMember();

        if (prop.proposer == address(0)) revert NotCurrentProposal();

        if (prop.creationTime != 0) revert Sponsored();

        prop.prevProposal = currentSponsoredProposal;

        currentSponsoredProposal = proposal;

        prop.creationTime = _safeCastTo32(block.timestamp);

        emit ProposalSponsored(msg.sender, proposal);
    } 

    function vote(uint256 proposal, bool approve) public payable virtual {
        _vote(
            msg.sender, 
            proposal, 
            approve
        );
    }
    
    function voteBySig(
        uint256 proposal, 
        bool approve, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) public payable virtual {
        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                'SignVote(uint256 proposal,bool approve)'
                            ),
                            proposal,
                            approve
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        if (recoveredAddress == address(0)) revert InvalidSignature();
        
        _vote(
            recoveredAddress, 
            proposal, 
            approve
        );
    }
    
    function _vote(
        address signer, 
        uint256 proposal, 
        bool approve
    ) internal virtual {
        Proposal storage prop = proposals[proposal];

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
        
        emit VoteCast(
            signer, 
            proposal, 
            approve, 
            weight
        );
    }

    function processProposal(
        uint256 proposal,
        ProposalType proposalType,
        bytes32 description,
        address[] calldata accounts, 
        uint256[] calldata amounts, 
        bytes[] calldata payloads
    ) public payable nonReentrant virtual returns (bool didProposalPass, bytes[] memory results) {
        Proposal storage prop = proposals[proposal];

        { // scope to avoid stack too deep error
        VoteType voteType = proposalVoteTypes[proposalType];

        if (prop.creationTime == 0) revert NotCurrentProposal();

        bytes32 proposalHash = keccak256(
            abi.encode(
                proposalType,
                description,
                accounts,
                amounts,
                payloads
            )
        );

        if (proposalHash != prop.proposalHash) revert NotCurrentProposal();

        // skip previous proposal processing requirement in case of escape hatch
        if (proposalType != ProposalType.ESCAPE) 
            if (proposals[prop.prevProposal].creationTime != 0) revert PrevNotProcessed();

        didProposalPass = _countVotes(voteType, prop.yesVotes, prop.noVotes);
        } // end scope
        
        // this is safe from overflow because `votingPeriod` and `gracePeriod` are capped so they will not combine
        // with unix time to exceed the max uint256 value
        unchecked {
            if (!didProposalPass && gracePeriod != 0) {
                if (block.timestamp <= prop.creationTime + (
                    votingPeriod - (
                        block.timestamp - (prop.creationTime + votingPeriod))
                    ) 
                    + gracePeriod
                ) revert VotingNotEnded();
            }
        }
 
        if (didProposalPass) {
            // cannot realistically overflow on human timescales
            unchecked {
                if (proposalType == ProposalType.MINT) {
                    for (uint256 i; i < accounts.length; i++) {
                        _mint(accounts[i], amounts[i]);
                    }
                } else if (proposalType == ProposalType.BURN) { 
                    for (uint256 i; i < accounts.length; i++) {
                        _burn(accounts[i], amounts[i]);
                    }
                } else if (proposalType == ProposalType.CALL) {
                    for (uint256 i; i < accounts.length; i++) {
                        results = new bytes[](accounts.length);
                        
                        (, bytes memory result) = accounts[i].call{value: amounts[i]}
                            (payloads[i]);
                        
                        results[i] = result;
                    }
                } else if (proposalType == ProposalType.VPERIOD) {
                    if (amounts[0] != 0) votingPeriod = uint64(amounts[0]);
                } else if (proposalType == ProposalType.GPERIOD) {
                    if (amounts[0] != 0) gracePeriod = uint64(amounts[0]);
                } else if (proposalType == ProposalType.QUORUM) {
                    if (amounts[0] != 0) quorum = uint64(amounts[0]);
                } else if (proposalType == ProposalType.SUPERMAJORITY) {
                    if (amounts[0] != 0) supermajority = uint64(amounts[0]);
                } else if (proposalType == ProposalType.TYPE) {
                    proposalVoteTypes[ProposalType(amounts[0])] = VoteType(amounts[1]);
                } else if (proposalType == ProposalType.PAUSE) {
                    _flipPause();
                } else if (proposalType == ProposalType.EXTENSION) {
                    for (uint256 i; i < accounts.length; i++) {
                        if (amounts[i] != 0) 
                            extensions[accounts[i]] = !extensions[accounts[i]];
                    
                        if (payloads[i].length > 9) IKaliDAOxExtension(accounts[i])
                            .setExtension(payloads[i]);
                    }
                } else if (proposalType == ProposalType.ESCAPE) {
                    delete proposals[amounts[0]];
                } else if (proposalType == ProposalType.DOCS) {
                    daoURI = string(abi.encodePacked(description));
                }

                proposalStates[proposal].passed = true;
            }
        }

        delete proposals[proposal];

        proposalStates[proposal].processed = true;

        emit ProposalProcessed(proposal, didProposalPass);
    }

    function _countVotes(
        VoteType voteType,
        uint96 yesVotes,
        uint96 noVotes
    ) internal view virtual returns (bool didProposalPass) {
        // fail proposal if no participation
        if (yesVotes == 0 && noVotes == 0) return false;

        // rule out any failed quorums
        if (voteType == VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED || voteType == VoteType.SUPERMAJORITY_QUORUM_REQUIRED) {
            // this is safe from overflow because `yesVotes` and `noVotes` 
            // supply are checked in `KaliDAOtoken` contract
            unchecked {
                if (yesVotes + noVotes < totalSupply * quorum / 100) return false;
            }
        }
        
        // simple majority check
        if (voteType == VoteType.SIMPLE_MAJORITY || voteType == VoteType.SIMPLE_MAJORITY_QUORUM_REQUIRED) {
            if (yesVotes > noVotes) return true;
        // supermajority check
        } else {
            // example: 7 yes, 2 no, supermajority = 66
            // ((7+2) * 66) / 100 = 5.94; 7 yes will pass ~~
            // this is safe from overflow because `yesVotes` and `noVotes` 
            // supply are checked in `KaliDAOtoken` contract
            unchecked {
                if (yesVotes >= ((yesVotes + noVotes) * supermajority) / 100) return true;
            }
        }
    }
    
    /// -----------------------------------------------------------------------
    /// EXTENSION LOGIC
    /// -----------------------------------------------------------------------

    modifier onlyExtension {
        if (!extensions[msg.sender]) revert NotExtension();

        _;
    }

    function mintShares(address to, uint256 amount) public payable onlyExtension virtual {
        _mint(to, amount);
    }

    function burnShares(address from, uint256 amount) public payable onlyExtension virtual {
        _burn(from, amount);
    }

    function relay(
        address account,
        uint256 amount,
        bytes calldata payload
    ) public payable onlyExtension virtual returns (bool success, bytes memory result) {
        (success, result) = account.call{value: amount}(payload);
    }

    function setExtension(address extension, bool set) public payable onlyExtension virtual {
        extensions[extension] = set;

        emit ExtensionSet(extension, set);
    }

    function setURI(string calldata daoURI_) public payable onlyExtension virtual {
        daoURI = daoURI_;

        emit URIset(daoURI_);
    }

    function updateGovSettings(
        uint64 votingPeriod_,
        uint64 gracePeriod_,
        uint64 quorum_,
        uint64 supermajority_
    ) public payable onlyExtension virtual {
        if (votingPeriod_ != 0) votingPeriod = votingPeriod_;

        if (gracePeriod_ != 0) gracePeriod = gracePeriod_;

        if (quorum_ != 0) quorum = quorum_;

        if (supermajority_ != 0) supermajority = supermajority_;

        emit GovSettingsUpdated(
            votingPeriod_, 
            gracePeriod_, 
            quorum_, 
            supermajority_
        );
    }
}

/// @title ClonesWithImmutableArgs
/// @author wighawag, zefram.eth, Saw-mon & Natalie, wminshew
/// @notice Enables creating clone contracts with immutable args
/// @dev extended by will@0xsplits.xyz to add receive() without DELEGECALL & create2 support
/// (h/t WyseNynja https://github.com/wighawag/clones-with-immutable-args/issues/4)
library ClonesWithImmutableArgs {
    error CreateFail();

    uint256 private constant FREE_MEMORY_POINTER_SLOT = 0x40;
    uint256 private constant BOOTSTRAP_LENGTH = 0x6f;
    uint256 private constant RUNTIME_BASE = 0x65; // BOOTSTRAP_LENGTH - 10 bytes
    uint256 private constant ONE_WORD = 0x20;
    // = keccak256("ReceiveETH(uint256)")
    uint256 private constant RECEIVE_EVENT_SIG =
        0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff;

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return ptr The ptr to the clone's bytecode
    /// @return creationSize The size of the clone to be created
    function cloneCreationCode(address implementation, bytes memory data)
        internal
        pure
        returns (uint256 ptr, uint256 creationSize)
    {
        // unrealistic for memory ptr or data length to exceed 256 bits
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let extraLength := add(mload(data), 2) // +2 bytes for telling how much data there is appended to the call
            creationSize := add(extraLength, BOOTSTRAP_LENGTH)
            let runSize := sub(creationSize, 0x0a)

            // free memory pointer
            ptr := mload(FREE_MEMORY_POINTER_SLOT)

            // -------------------------------------------------------------------------------------------------------------
            // CREATION (10 bytes)
            // -------------------------------------------------------------------------------------------------------------

            // 61 runtime  | PUSH2 runtime (r)     | r                       | –
            // 3d          | RETURNDATASIZE        | 0 r                     | –
            // 81          | DUP2                  | r 0 r                   | –
            // 60 offset   | PUSH1 offset (o)      | o r 0 r                 | –
            // 3d          | RETURNDATASIZE        | 0 o r 0 r               | –
            // 39          | CODECOPY              | 0 r                     | [0, runSize): runtime code
            // f3          | RETURN                |                         | [0, runSize): runtime code

            // -------------------------------------------------------------------------------------------------------------
            // RUNTIME (101 bytes + extraLength)
            // -------------------------------------------------------------------------------------------------------------

            // --- if no calldata, emit event & return w/o `DELEGATECALL`
            //     0x000     36       calldatasize      cds                  | -
            //     0x001     602f     push1 0x2f        0x2f cds             | -
            // ,=< 0x003     57       jumpi                                  | -
            // |   0x004     34       callvalue         cv                   | -
            // |   0x005     3d       returndatasize    0 cv                 | -
            // |   0x006     52       mstore                                 | [0, 0x20) = cv
            // |   0x007     7f9e4a.. push32 0x9e4a..   id                   | [0, 0x20) = cv
            // |   0x028     6020     push1 0x20        0x20 id              | [0, 0x20) = cv
            // |   0x02a     3d       returndatasize    0 0x20 id            | [0, 0x20) = cv
            // |   0x02b     a1       log1                                   | [0, 0x20) = cv
            // |   0x02c     3d       returndatasize    0                    | [0, 0x20) = cv
            // |   0x02d     3d       returndatasize    0 0                  | [0, 0x20) = cv
            // |   0x02e     f3       return
            // `-> 0x02f     5b       jumpdest

            // --- copy calldata to memory ---
            // 36          | CALLDATASIZE          | cds                     | –
            // 3d          | RETURNDATASIZE        | 0 cds                   | –
            // 3d          | RETURNDATASIZE        | 0 0 cds                 | –
            // 37          | CALLDATACOPY          |                         | [0 - cds): calldata

            // --- keep some values in stack ---
            // 3d          | RETURNDATASIZE        | 0                       | [0 - cds): calldata
            // 3d          | RETURNDATASIZE        | 0 0                     | [0 - cds): calldata
            // 3d          | RETURNDATASIZE        | 0 0 0                   | [0 - cds): calldata
            // 3d          | RETURNDATASIZE        | 0 0 0 0                 | [0 - cds): calldata
            // 61 extra    | PUSH2 extra (e)       | e 0 0 0 0               | [0 - cds): calldata

            // --- copy extra data to memory ---
            // 80          | DUP1                  | e e 0 0 0 0             | [0 - cds): calldata
            // 60 rb       | PUSH1 rb              | rb e e 0 0 0 0          | [0 - cds): calldata
            // 36          | CALLDATASIZE          | cds rb e e 0 0 0 0      | [0 - cds): calldata
            // 39          | CODECOPY              | e 0 0 0 0               | [0 - cds): calldata, [cds - cds + e): extraData

            // --- delegate call to the implementation contract ---
            // 36          | CALLDATASIZE          | cds e 0 0 0 0           | [0 - cds): calldata, [cds - cds + e): extraData
            // 01          | ADD                   | cds+e 0 0 0 0           | [0 - cds): calldata, [cds - cds + e): extraData
            // 3d          | RETURNDATASIZE        | 0 cds+e 0 0 0 0         | [0 - cds): calldata, [cds - cds + e): extraData
            // 73 addr     | PUSH20 addr           | addr 0 cds+e 0 0 0 0    | [0 - cds): calldata, [cds - cds + e): extraData
            // 5a          | GAS                   | gas addr 0 cds+e 0 0 0 0| [0 - cds): calldata, [cds - cds + e): extraData
            // f4          | DELEGATECALL          | success 0 0             | [0 - cds): calldata, [cds - cds + e): extraData

            // --- copy return data to memory ---
            // 3d          | RETURNDATASIZE        | rds success 0 0         | [0 - cds): calldata, [cds - cds + e): extraData
            // 3d          | RETURNDATASIZE        | rds rds success 0 0     | [0 - cds): calldata, [cds - cds + e): extraData
            // 93          | SWAP4                 | 0 rds success 0 rds     | [0 - cds): calldata, [cds - cds + e): extraData
            // 80          | DUP1                  | 0 0 rds success 0 rds   | [0 - cds): calldata, [cds - cds + e): extraData
            // 3e          | RETURNDATACOPY        | success 0 rds           | [0 - rds): returndata, ... the rest might be dirty

            // 60 0x63     | PUSH1 0x63            | 0x63 success            | [0 - rds): returndata, ... the rest might be dirty
            // 57          | JUMPI                 |                         | [0 - rds): returndata, ... the rest might be dirty

            // --- revert ---
            // fd          | REVERT                |                         | [0 - rds): returndata, ... the rest might be dirty

            // --- return ---
            // 5b          | JUMPDEST              |                         | [0 - rds): returndata, ... the rest might be dirty
            // f3          | RETURN                |                         | [0 - rds): returndata, ... the rest might be dirty

            mstore(
                ptr,
                or(
                    hex"6100003d81600a3d39f336602f57343d527f", // 18 bytes
                    shl(0xe8, runSize)
                )
            )

            mstore(
                   add(ptr, 0x12), // 0x0 + 0x12
                RECEIVE_EVENT_SIG // 32 bytes
            )

            mstore(
                   add(ptr, 0x32), // 0x12 + 0x20
                or(
                    hex"60203da13d3df35b363d3d373d3d3d3d610000806000363936013d73", // 28 bytes
                    or(shl(0x68, extraLength), shl(0x50, RUNTIME_BASE))
                )
            )

            mstore(
                   add(ptr, 0x4e), // 0x32 + 0x1c
                shl(0x60, implementation) // 20 bytes
            )

            mstore(
                   add(ptr, 0x62), // 0x4e + 0x14
                hex"5af43d3d93803e606357fd5bf3" // 13 bytes
            )

            // -------------------------------------------------------------------------------------------------------------
            // APPENDED DATA (Accessible from extcodecopy)
            // (but also send as appended data to the delegatecall)
            // -------------------------------------------------------------------------------------------------------------

            let counter := mload(data)
            let copyPtr := add(ptr, BOOTSTRAP_LENGTH)
            let dataPtr := add(data, ONE_WORD)

            for {} true {} {
                if lt(counter, ONE_WORD) { break }

                mstore(copyPtr, mload(dataPtr))

                copyPtr := add(copyPtr, ONE_WORD)
                dataPtr := add(dataPtr, ONE_WORD)

                counter := sub(counter, ONE_WORD)
            }

            let mask := shl(mul(0x8, sub(ONE_WORD, counter)), not(0))

            mstore(copyPtr, and(mload(dataPtr), mask))
            copyPtr := add(copyPtr, counter)
            mstore(copyPtr, shl(0xf0, extraLength))

            // Update free memory pointer
            mstore(FREE_MEMORY_POINTER_SLOT, add(ptr, creationSize))
        }
    }

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function clone(address implementation, bytes memory data)
        internal
        returns (address payable instance)
    {
        (uint256 creationPtr, uint256 creationSize) =
            cloneCreationCode(implementation, data);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            instance := create(0, creationPtr, creationSize)
        }

        // if the create failed, the instance address won't be set
        if (instance == address(0)) {
            revert CreateFail();
        }
    }

    /// @notice Creates a clone proxy of the implementation contract with immutable args
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return instance The address of the created clone
    function cloneDeterministic(
        address implementation,
        bytes32 salt,
        bytes memory data
    )
        internal
        returns (address payable instance)
    {
        (uint256 creationPtr, uint256 creationSize) =
            cloneCreationCode(implementation, data);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            instance := create2(0, creationPtr, creationSize, salt)
        }

        // if the create failed, the instance address won't be set
        if (instance == address(0)) {
            revert CreateFail();
        }
    }

    /// @notice Predicts the address where a deterministic clone of implementation will be deployed
    /// @dev data cannot exceed 65535 bytes, since 2 bytes are used to store the data length
    /// @param implementation The implementation contract to clone
    /// @param salt The salt for create2
    /// @param data Encoded immutable args
    /// @return predicted The predicted address of the created clone
    /// @return exists Whether the clone already exists
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        bytes memory data
    )
        internal
        view
        returns (address predicted, bool exists)
    {
        (uint256 creationPtr, uint256 creationSize) =
            cloneCreationCode(implementation, data);

        bytes32 creationHash;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            creationHash := keccak256(creationPtr, creationSize)
        }

        predicted = computeAddress(salt, creationHash, address(this));
        exists = predicted.code.length > 0;
    }

    /// @dev Returns the address where a contract will be stored if deployed via CREATE2 from a contract located at `deployer`.
    function computeAddress(
        bytes32 salt,
        bytes32 bytecodeHash,
        address deployer
    )
        internal
        pure
        returns (address)
    {
        bytes32 _data =
            keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash));
        return address(uint160(uint256(_data)));
    }
}

/// @notice Factory to deploy Kali DAO.
contract KaliDAOxFactory is Multicallable {
    using ClonesWithImmutableArgs for address;

    event DAOdeployed(
        bytes32 name, 
        bytes32 symbol, 
        string daoURI, 
        bool paused, 
        address[] extensions, 
        bytes[] extensionsData,
        address[] voters,
        uint256[] shares,
        uint64[16] govSettings
    );

    error NullDeploy();

    KaliDAOx internal immutable kaliMaster;

    constructor(KaliDAOx kaliMaster_) payable {
        kaliMaster = kaliMaster_;
    }

    function determineKaliDAO(bytes32 name_, bytes32 symbol_)
        public
        view
        virtual
        returns (address kaliDAO, bool deployed)
    {
        (kaliDAO, deployed) = address(kaliMaster).predictDeterministicAddress(
            name_,
            abi.encodePacked(
                name_, 
                symbol_, 
                block.chainid
            )
        );
    }
    
    function deployKaliDAO(
        bytes32 name_,
        bytes32 symbol_,
        string memory daoURI_,
        bool paused_,
        address[] memory extensions_,
        bytes[] calldata extensionsData_,
        address[] calldata voters_,
        uint256[] calldata shares_,
        uint64[16] calldata govSettings_
    ) public payable virtual {
        KaliDAOx kaliDAO = KaliDAOx(
            address(kaliMaster).cloneDeterministic(
                name_,
                abi.encodePacked(
                    name_, 
                    symbol_, 
                    block.chainid
                )
            )
        );
        
        kaliDAO.init{value: msg.value}(
            daoURI_,
            paused_, 
            extensions_,
            extensionsData_,
            voters_, 
            shares_,  
            govSettings_
        );

        emit DAOdeployed(
            name_, 
            symbol_, 
            daoURI_, 
            paused_, 
            extensions_, 
            extensionsData_, 
            voters_, 
            shares_, 
            govSettings_
        );
    }
}
