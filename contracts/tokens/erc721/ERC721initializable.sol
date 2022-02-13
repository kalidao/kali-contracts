// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
/// License-Identifier: AGPL-3.0-only
interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/// @notice Modern and gas efficient ERC-721 + ERC-20/EIP-2612-like implementation.
abstract contract ERC721initializable {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event PauseFlipped(bool paused);

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error Paused();
    error NotApproved();
    error NotOwner();
    error InvalidRecipient();
    error SignatureExpired();
    error InvalidSignature();
    error AlreadyMinted();
    error NotMinted();

    /// -----------------------------------------------------------------------
    /// Metadata Storage/Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 tokenId) public view virtual returns (string memory);

    function name() public pure virtual returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0)));
    }

    function symbol() public pure virtual returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(0x20)));
    }

    function _getArgUint256(uint256 argOffset) internal pure virtual returns (uint256 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    function _getImmutableArgsOffset() internal pure virtual returns (uint256 offset) {
        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC-721 Storage
    /// -----------------------------------------------------------------------
    
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /// -----------------------------------------------------------------------
    /// EIP-2612 Storage
    /// -----------------------------------------------------------------------
    
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256('Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)');
    bytes32 public constant PERMIT_ALL_TYPEHASH = 
        keccak256('Permit(address owner,address spender,uint256 nonce,uint256 deadline)');
    uint256 internal INITIAL_CHAIN_ID;
    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    mapping(uint256 => uint256) public nonces;
    mapping(address => uint256) public noncesForAll;

    /// -----------------------------------------------------------------------
    /// Pause Storage/Logic
    /// -----------------------------------------------------------------------

    bool public paused;

    modifier notPaused() {
        if (paused) revert Paused();
        _;
    }
    
    /// -----------------------------------------------------------------------
    /// Initializer
    /// -----------------------------------------------------------------------
    
    function _init(bool paused_) internal virtual {
        paused = paused_;
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }
    
    /// -----------------------------------------------------------------------
    /// ERC-20 Logic
    /// -----------------------------------------------------------------------
    
    function transfer(address to, uint256 tokenId) public notPaused virtual returns (bool) {
        if (msg.sender != ownerOf[tokenId]) revert NotOwner();
        if (to == address(0)) revert InvalidRecipient();
        
        // underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow
        unchecked {
            balanceOf[msg.sender]--; 
            balanceOf[to]++;
        }
        
        delete getApproved[tokenId];
        
        ownerOf[tokenId] = to;
        
        emit Transfer(msg.sender, to, tokenId); 
        
        return true;
    }

    /// -----------------------------------------------------------------------
    /// ERC-721 Logic
    /// -----------------------------------------------------------------------
    
    function approve(address spender, uint256 tokenId) public virtual {
        address owner = ownerOf[tokenId];

        if (msg.sender != owner && !isApprovedForAll[owner][msg.sender]) revert NotApproved();
        
        getApproved[tokenId] = spender;
        
        emit Approval(owner, spender, tokenId); 
    }
    
    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;
        
        emit ApprovalForAll(msg.sender, operator, approved);
    }
    
    function transferFrom(
        address from, 
        address to, 
        uint256 tokenId
    ) public notPaused virtual {
        if (from != ownerOf[tokenId]) revert NotOwner();
        if (to == address(0)) revert InvalidRecipient();
        if (msg.sender != from 
            && msg.sender != getApproved[tokenId]
            && !isApprovedForAll[from][msg.sender]
        ) revert NotApproved();  
        
        // underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow
        unchecked { 
            balanceOf[from]--; 
            balanceOf[to]++;
        }
        
        delete getApproved[tokenId];
        
        ownerOf[tokenId] = to;
        
        emit Transfer(from, to, tokenId); 
    }
    
    function safeTransferFrom(
        address from, 
        address to, 
        uint256 tokenId
    ) public notPaused virtual {
        transferFrom(from, to, tokenId); 

        if (to.code.length != 0 
            && ERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, '') 
            != ERC721TokenReceiver.onERC721Received.selector
        ) revert InvalidRecipient();
    }
    
    function safeTransferFrom(
        address from, 
        address to, 
        uint256 tokenId, 
        bytes memory data
    ) public notPaused virtual {
        transferFrom(from, to, tokenId); 
        
        if (to.code.length != 0 
            && ERC721TokenReceiver(to).onERC721Received(msg.sender, from, tokenId, data) 
            != ERC721TokenReceiver.onERC721Received.selector
        ) revert InvalidRecipient();
    }

    /// -----------------------------------------------------------------------
    /// ERC-165 Logic
    /// -----------------------------------------------------------------------

    function supportsInterface(bytes4 interfaceId) public pure virtual returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165 Interface ID for ERC-165
            interfaceId == 0x80ac58cd || // ERC-165 Interface ID for ERC-721
            interfaceId == 0x5b5e139f; // ERC-165 Interface ID for ERC721Metadata
    }

    /// -----------------------------------------------------------------------
    /// EIP-2612 Logic
    /// -----------------------------------------------------------------------
    
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) revert SignatureExpired();
        
        address owner = ownerOf[tokenId];
        
        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, spender, tokenId, nonces[tokenId]++, deadline))
                )
            );

            address recoveredAddress = ecrecover(digest, v, r, s);

            if (recoveredAddress == address(0)) revert InvalidSignature();
            if (recoveredAddress != owner && !isApprovedForAll[owner][recoveredAddress]) revert InvalidSignature(); 
        }
        
        getApproved[tokenId] = spender;

        emit Approval(owner, spender, tokenId);
    }
    
    function permitAll(
        address owner,
        address operator,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        if (block.timestamp > deadline) revert SignatureExpired();
        
        // cannot realistically overflow on human timescales
        unchecked {
            bytes32 digest = keccak256(
                abi.encodePacked(
                    '\x19\x01',
                    DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_ALL_TYPEHASH, owner, operator, noncesForAll[owner]++, deadline))
                )
            );

            address recoveredAddress = ecrecover(digest, v, r, s);

            if (recoveredAddress == address(0)) revert InvalidSignature();
            if (recoveredAddress != owner && !isApprovedForAll[owner][recoveredAddress]) revert InvalidSignature();
        }
        
        isApprovedForAll[owner][operator] = true;

        emit ApprovalForAll(owner, operator, true);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return 
            keccak256(
                abi.encode(
                    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                    keccak256(bytes(name())),
                    keccak256('1'),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// Internal Mint/Burn Logic
    /// -----------------------------------------------------------------------
    
    function _mint(address to, uint256 tokenId) internal virtual { 
        if (to == address(0)) revert InvalidRecipient();
        if (ownerOf[tokenId] != address(0)) revert AlreadyMinted();
  
        // cannot realistically overflow on human timescales
        unchecked {
            totalSupply++;
            balanceOf[to]++;
        }
        
        ownerOf[tokenId] = to;
        
        emit Transfer(address(0), to, tokenId); 
    }
    
    function _burn(uint256 tokenId) internal virtual { 
        address owner = ownerOf[tokenId];

        if (ownerOf[tokenId] == address(0)) revert NotMinted();
        
        // ownership check ensures no underflow
        unchecked {
            totalSupply--;
            balanceOf[owner]--;
        }
        
        delete ownerOf[tokenId];
        delete getApproved[tokenId];
        
        emit Transfer(owner, address(0), tokenId); 
    }

    /// -----------------------------------------------------------------------
    /// Internal Safe Mint Logic
    /// -----------------------------------------------------------------------

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _mint(to, tokenId);

        if (to.code.length != 0 
            && ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), tokenId, '') 
            != ERC721TokenReceiver.onERC721Received.selector
        ) revert InvalidRecipient();
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);

        if (to.code.length != 0 
            && ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), tokenId, data) 
            != ERC721TokenReceiver.onERC721Received.selector
        ) revert InvalidRecipient();
    }

    /// -----------------------------------------------------------------------
    /// Internal Pause Logic
    /// -----------------------------------------------------------------------

    function _flipPause() internal virtual {
        paused = !paused;

        emit PauseFlipped(paused);
    }
}
