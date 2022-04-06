// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {MerkleProof} from '../libraries/MerkleProof.sol';

import {Multicall} from '../utils/Multicall.sol';

import {ERC1155 as SolmateERC1155} from 'https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC1155.sol';

/// @notice Kali DAO access manager
/// @author Modified from SushiSwap
/// (https://github.com/sushiswap/trident/blob/master/contracts/pool/franchised/WhiteListManager.sol)
/// License-Identifier: GPL-3.0-or-later
contract KaliAccessManager is Multicall, SolmateERC1155 {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using MerkleProof for bytes32[];

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ListCreated(address indexed operator, uint256 indexed id);
    event MerkleRootSet(uint256 indexed id, bytes32 merkleRoot);
    event ListJoined(address indexed account, uint256 indexed id);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotOperator();
    error NoArrayParity();
    error SignatureExpired();
    error InvalidSignature();
    error ListClaimed();
    error InvalidList();
    error NotOnList();

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage
    /// -----------------------------------------------------------------------

    uint256 private immutable INITIAL_CHAIN_ID;
    bytes32 private immutable INITIAL_DOMAIN_SEPARATOR;
    bytes32 private constant LIST_TYPEHASH =
        keccak256('List(address account,uint256 id,bool approved,uint256 deadline)');

    /// -----------------------------------------------------------------------
    /// List Storage
    /// -----------------------------------------------------------------------

    uint256 public listCount;

    mapping(uint256 => address) public operatorOf;
    mapping(uint256 => bytes32) public merkleRoots;
    mapping(uint256 => string) public uris;

    function uri(uint256 id) public override view returns (string memory) {
        return uris[id];
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    /// -----------------------------------------------------------------------
    /// EIP-712 Logic
    /// -----------------------------------------------------------------------

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                    keccak256(bytes('KaliAccessManager')),
                    keccak256('1'),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// List Logic
    /// -----------------------------------------------------------------------

    function createList(
        address[] calldata accounts, 
        bytes32 merkleRoot, 
        string calldata metadata
    ) external {
        uint256 id = ++listCount;

        operatorOf[id] = msg.sender;

        if (accounts.length != 0) {
            for (uint256 i; i < accounts.length; ) {
                _listAccount(accounts[i], id, true);
                // cannot realistically overflow on human timescales
                unchecked {
                    ++i;
                }
            }

            emit ListCreated(msg.sender, id);
        }

        if (merkleRoot != '') {
            merkleRoots[id] = merkleRoot;
            emit MerkleRootSet(id, merkleRoot);
        }

        uris[id] = metadata;
    }

    function listAccounts(
        uint256 id,
        address[] calldata accounts,
        bool[] calldata approvals
    ) external {
        if (msg.sender != operatorOf[id]) revert NotOperator();
        if (accounts.length != approvals.length) revert NoArrayParity();

        for (uint256 i; i < accounts.length; ) {
            _listAccount(accounts[i], id, approvals[i]);
            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }
    }

    function listAccountBySig(
        address account,
        uint256 id,
        bool approved,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if (block.timestamp > deadline) revert SignatureExpired();

        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR(),
                keccak256(abi.encode(LIST_TYPEHASH, account, id, approved, deadline))
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);

        if (recoveredAddress == address(0) || recoveredAddress != operatorOf[id]) revert InvalidSignature();

        _listAccount(account, id, approved);
    }

    function _listAccount(
        address account,
        uint256 id,
        bool approved
    ) private {
        approved ? _mint(account, id, 1, '') : _burn(account, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Merkle Logic
    /// -----------------------------------------------------------------------

    function setMerkleRoot(uint256 id, bytes32 merkleRoot) external {
        if (msg.sender != operatorOf[id]) revert NotOperator();

        merkleRoots[id] = merkleRoot;

        emit MerkleRootSet(id, merkleRoot);
    }

    function joinList(
        address account,
        uint256 id,
        bytes32[] calldata merkleProof
    ) external {
        if (balanceOf[account][id] != 0) revert ListClaimed();
        if (merkleRoots[id] == 0) revert InvalidList();
        if (!merkleProof.verify(merkleRoots[id], keccak256(abi.encodePacked(account)))) revert NotOnList();

        _listAccount(account, id, true);

        emit ListJoined(account, id);
    }
}
