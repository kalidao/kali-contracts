// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.4;

import "../ERC721.sol";

/// @notice Public NFT minter for Kali DAO.
contract KaliNFT is ERC721, Multicall {
    mapping(uint256 => string) private _tokenURI;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}
    
    function tokenURI(uint256 tokenId) public view override virtual returns (string memory) {
        return _tokenURI[tokenId];
    }

    function mint(
        address to, 
        uint256 tokenId,
        string calldata uri
    ) public virtual {
        _mint(to, tokenId);

        _tokenURI[tokenId] = uri;
    }

    function burn(uint256 tokenId) public virtual {
        if (msg.sender != ownerOf[tokenId]) revert NotOwner();

        _burn(tokenId);
    }
}
