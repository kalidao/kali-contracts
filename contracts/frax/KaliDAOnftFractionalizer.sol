// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

interface IERC721minimal {
    function transferFrom(address from, address to, uint256 id) external;
}

interface IKaliDAOfactory {
    function deployKaliDAO(
        string memory name_,
        string memory symbol_,
        string memory docs_,
        bool paused_,
        address[] memory extensions_,
        bytes[] memory extensionsData_,
        address[] calldata voters_,
        uint256[] calldata shares_,
        uint32[16] memory govSettings_
    ) external payable returns (address);
}

contract KaliDAOnftFractionalizer {
    IKaliDAOfactory private immutable kaliDAOfactory;

    constructor (IKaliDAOfactory kaliDAOfactory_) {
        kaliDAOfactory = kaliDAOfactory_;
    }

    struct NFT {
        IERC721minimal nft;
        uint256 id;
    }
    
    function fractionalize(
        string memory name_,
        string memory symbol_,
        bool paused_,
        address[] memory extensions_,
        bytes[] memory extensionsData_,
        address[] calldata voters_,
        uint256[] calldata shares_,
        uint32[16] memory govSettings_,
        NFT[] memory nfts_
    ) external payable returns (address kaliDAO) {
        kaliDAO = kaliDAOfactory.deployKaliDAO(
            name_, 
            symbol_, 
            "FRAX",
            paused_, 
            extensions_,
            extensionsData_,
            voters_, 
            shares_,  
            govSettings_
        );

        for (uint256 i; i < nfts_.length; ) {
            nfts_[i].nft.transferFrom(msg.sender, kaliDAO, nfts_[i].id);
            // cannot realistically overflow on human timescales
            unchecked {
                ++i;
            }
        }
    }
}
