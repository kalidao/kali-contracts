// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import '../utils/Multicall.sol';

/// @notice Merkle library adapted from https://github.com/miguelmota/merkletreejs[merkletreejs].
library MerkleProof {
    /// @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
    /// defined by `root`. For this, a `proof` must be provided, containing
    /// sibling hashes on the branch from the leaf to the root of the tree. Each
    /// pair of leaves and each pair of pre-images are assumed to be sorted.
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

/// @notice Kali DAO access manager.
/// @author Modified from SushiSwap
/// (https://github.com/sushiswap/trident/blob/master/contracts/pool/franchised/WhiteListManager.sol)
contract KaliAccessManager {
    using MerkleProof for bytes32[];

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event WhitelistCreated(uint256 indexed listId, address indexed operator);

    event AccountWhitelisted(uint256 indexed listId, address indexed account, bool approved);

    event MerkleRootSet(uint256 indexed listId, bytes32 merkleRoot);

    event WhitelistJoined(uint256 indexed listId, address indexed account);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOperator();

    error SignatureExpired();

    error InvalidSignature();

    error WhitelistClaimed();

    error InvalidWhiteList();

    error NotOnWhitelist();

    /*///////////////////////////////////////////////////////////////
                            EIP-712 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    bytes32 internal constant WHITELIST_TYPEHASH =
        keccak256('Whitelist(address account,bool approved,uint256 deadline)');

    /*///////////////////////////////////////////////////////////////
                            WHITELIST STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) public operatorOf;

    mapping(uint256 => bytes32) public merkleRoots;

    mapping(uint256 => mapping(address => bool)) public whitelistedAccounts;

    uint256 public listCount;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;

        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();

        listCount = 0;
    }

    /*///////////////////////////////////////////////////////////////
                            EIP-712 LOGIC
    //////////////////////////////////////////////////////////////*/

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                    keccak256(bytes('KaliWhitelistManager')),
                    keccak256('1'),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*///////////////////////////////////////////////////////////////
                            WHITELIST LOGIC
    //////////////////////////////////////////////////////////////*/

    function createWhitelist(
        address[] calldata accounts,
        bytes32 merkleRoot
    ) public virtual {
        listCount++;

        uint256 listId = listCount;

        operatorOf[listId] = msg.sender;

        if (accounts.length != 0) {
            // cannot realistically overflow on human timescales
            unchecked {
                for (uint256 i; i < accounts.length; i++) {
                    _whitelistAccount(listId, accounts[i], true);
                }
            }

            emit WhitelistCreated(listId, msg.sender);
        }

        if (merkleRoot != '') {
            merkleRoots[listId] = merkleRoot;

            emit MerkleRootSet(listId, merkleRoot);
        }
    }

    function isWhitelisted(uint256 listId, address account) public view virtual returns (bool) {
        return whitelistedAccounts[listId][account];
    }

    function whitelistAccounts(
        uint256 listId,
        address[] calldata accounts,
        bool[] calldata approvals
    ) public virtual {
        if (msg.sender != operatorOf[listId]) revert NotOperator();

        // cannot realistically overflow on human timescales
        unchecked {
            for (uint256 i; i < accounts.length; i++) {
                _whitelistAccount(listId, accounts[i], approvals[i]);
            }
        }
    }

    function whitelistAccountBySig(
        uint256 listId,
        address account,
        bool approved,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) revert SignatureExpired();

        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(WHITELIST_TYPEHASH, account, approved, deadline))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);

        if (recoveredAddress != operatorOf[listId]) revert InvalidSignature();

        _whitelistAccount(listId, account, approved);
    }

    function _whitelistAccount(
        uint256 listId,
        address account,
        bool approved
    ) internal virtual {
        whitelistedAccounts[listId][account] = approved;

        emit AccountWhitelisted(listId, account, approved);
    }

    /*///////////////////////////////////////////////////////////////
                            MERKLE LOGIC
    //////////////////////////////////////////////////////////////*/

    function setMerkleRoot(uint256 listId, bytes32 merkleRoot) public virtual {
        if (msg.sender != operatorOf[listId]) revert NotOperator();

        merkleRoots[listId] = merkleRoot;

        emit MerkleRootSet(listId, merkleRoot);
    }

    function joinWhitelist(
        uint256 listId,
        address account,
        bytes32[] calldata merkleProof
    ) public virtual {
        if (isWhitelisted(listId, account)) revert WhitelistClaimed();

        if (merkleRoots[listId] == 0) revert InvalidWhiteList();

        if (!merkleProof.verify(merkleRoots[listId], keccak256(abi.encodePacked(account)))) revert NotOnWhitelist();

        _whitelistAccount(listId, account, true);

        emit WhitelistJoined(listId, account);
    }
}
