// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./IERC721J.sol";

interface IERC721JFull is IERC721J {

    // Event to show which tokens were created by recycling
    event Recycle(uint256 tokenId, address recycleAddress);

    // Mint a copy with an erc-20 token
    function mintCopyToken(uint256 tokenId, address token) external;

    // Mint a copy with an erc-20 token to a wallet address of your choice
    function mintCopyTokenTo(
        uint256 tokenId,
        address token,
        address to
    ) external;

    // Returns status of public mint for tokenId
    function publicMint(uint256 tokenId) external view returns (bool);

    // Returns the percent price multiplier for a rarity
    function rarityMultiplier(uint256 generation)
        external
        view
        returns (uint256 multiplierPercent);

    // Recycle mint burns 2 tokens to mint 1
    function recycleMint(uint256 mintTokenId, 
        uint256 burnTokenId1, 
        uint256 burnTokenId2) 
        external;

    // Returns the mint price for an erc-20 token address
    function tokenMintPrice(address token) external view returns (uint256);

}

