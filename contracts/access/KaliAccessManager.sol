// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {MerkleProof} from '../libraries/MerkleProof.sol';
import {SVG} from '../libraries/SVG.sol';
import {JSON} from '../libraries/JSON.sol';

import {Multicall} from '../utils/Multicall.sol';

import {NTERC1155} from '../tokens/erc1155/NTERC1155.sol';

/// @notice Kali DAO access manager
contract KaliAccessManager is Multicall, NTERC1155 {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using MerkleProof for bytes32[];

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ListCreated(address indexed operator, uint256 id);
    event MerkleRootSet(uint256 id, bytes32 merkleRoot);
    event AccountListed(address indexed account, uint256 id, bool approved);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotOperator();
    error SignatureExpired();
    error InvalidSignature();
    error ListClaimed();
    error NotListed();

    /// -----------------------------------------------------------------------
    /// EIP-712 Storage
    /// -----------------------------------------------------------------------

    uint256 private immutable INITIAL_CHAIN_ID;
    bytes32 private immutable INITIAL_DOMAIN_SEPARATOR;

    /// -----------------------------------------------------------------------
    /// List Storage
    /// -----------------------------------------------------------------------

    uint256 public listCount;

    string public constant name = "Access";
    string public constant symbol = "AXS";

    mapping(uint256 => address) public operatorOf;
    mapping(uint256 => bytes32) public merkleRoots;
    mapping(uint256 => string) private uris;
    
    modifier onlyOperator() {
        if (msg.sender != operatorOf[id]) revert NotOperator();
        _;
    }

    struct Listing {
        address account;
        bool approval;
    }

    function uri(uint256 id) public view override returns (string memory) {
        if (bytes(uris[id]).length == 0) {
            return _buildURI(id);
        } else {
            return uris[id];
        }
    }
    
    function _buildURI(uint256 id) private pure returns (string memory) {
        return
            JSON._formattedMetadata(
                string.concat('Access #', SVG._uint2str(id)), 
                'Kali Access Manager', 
                string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#191919">',
                SVG._text(
                    string.concat(
                        SVG._prop('x', '20'),
                        SVG._prop('y', '40'),
                        SVG._prop('font-size', '22'),
                        SVG._prop('fill', 'white')
                    ),
                    string.concat(
                        SVG._cdata('Access List #'),
                        SVG._uint2str(id)
                    )
                ),
                SVG._rect(
                    string.concat(
                        SVG._prop('fill', 'maroon'),
                        SVG._prop('x', '20'),
                        SVG._prop('y', '50'),
                        SVG._prop('width', SVG._uint2str(160)),
                        SVG._prop('height', SVG._uint2str(10))
                    ),
                    SVG.NULL
                ),
                SVG._text(
                    string.concat(
                        SVG._prop('x', '20'),
                        SVG._prop('y', '90'),
                        SVG._prop('font-size', '12'),
                        SVG._prop('fill', 'white')
                    ),
                    string.concat(
                        SVG._cdata('The holder of this token can enjoy')
                    )
                ),
                SVG._text(
                    string.concat(
                        SVG._prop('x', '20'),
                        SVG._prop('y', '110'),
                        SVG._prop('font-size', '12'),
                        SVG._prop('fill', 'white')
                    ),
                    string.concat(SVG._cdata('access to restricted functions.'))
                ),
                SVG._image(
                    'https://gateway.pinata.cloud/ipfs/Qmb2AWDjE8GNUob83FnZfuXLj9kSs2uvU9xnoCbmXhH7A1', 
                    string.concat(
                        SVG._prop('x', '215'),
                        SVG._prop('y', '220'),
                        SVG._prop('width', '80')
                    )
                ),
                '</svg>'
            )
        );
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
    ) external payable returns (uint256 id) {
        // cannot realistically overflow on human timescales
        unchecked {
            id = ++listCount;
        }

        operatorOf[id] = msg.sender;

        if (accounts.length != 0) {
            for (uint256 i; i < accounts.length; ) {
                _listAccount(accounts[i], id, true);
                // cannot realistically overflow on human timescales
                unchecked {
                    ++i;
                }
            }
        }

        if (merkleRoot != 0) {
            merkleRoots[id] = merkleRoot;
            emit MerkleRootSet(id, merkleRoot);
        }
        
        if (bytes(metadata).length != 0) {
            uris[id] = metadata;
            emit URI(metadata, id);
        }
        
        emit ListCreated(msg.sender, id);
    }

    function listAccounts(uint256 id, Listing[] calldata listings) external payable onlyOperator {
        for (uint256 i; i < listings.length; ) {
            _listAccount(listings[i].account, id, listings[i].approval);
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
    ) external payable {
        if (block.timestamp > deadline) revert SignatureExpired();

        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                'List(address account,uint256 id,bool approved,uint256 deadline)'
                            ),
                            account,
                            id,
                            approved,
                            deadline
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        if (recoveredAddress == address(0) || recoveredAddress != operatorOf[id]) revert InvalidSignature();

        _listAccount(account, id, approved);
    }

    function _listAccount(
        address account,
        uint256 id,
        bool approved
    ) private {
        approved ? _mint(account, id, 1, '') : _burn(account, id, 1);
        emit AccountListed(account, id, approved);
    }

    /// -----------------------------------------------------------------------
    /// Merkle Logic
    /// -----------------------------------------------------------------------

    function setMerkleRoot(uint256 id, bytes32 merkleRoot) external payable onlyOperator {
        if (msg.sender != operatorOf[id]) revert NotOperator();
        merkleRoots[id] = merkleRoot;
        emit MerkleRootSet(id, merkleRoot);
    }

    function claimList(
        address account,
        uint256 id,
        bytes32[] calldata merkleProof
    ) external payable {
        if (balanceOf[account][id] != 0) revert ListClaimed();
        if (!merkleProof.verify(merkleRoots[id], keccak256(abi.encodePacked(account)))) revert NotListed();

        _listAccount(account, id, true);
    }

    /// -----------------------------------------------------------------------
    /// URI Logic
    /// -----------------------------------------------------------------------

    function setURI(uint256 id, string calldata metadata) external payable onlyOperator {
        uris[id] = metadata;
        emit URI(metadata, id);
    }
}
