// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./IERC721J.sol";

interface IERC721JPromo is IERC721J {

     // Emits when a promo is set
    event SetPromo(
        address indexed contractName,
        uint256 songIn,
        uint256 songOut
    );

    // Takes a contract address and returns (if one exists) the promo claim set for that contract
    function promoCheck(address _contract)
        external
        view
        returns (uint256 _songIdOut, uint256 _generationOut, uint256 _promoPercentOut);

    // Takes a contract address, song and generation and returns (if one exists) the promo claim set for that specific set of tokens on that contract
    function promoCheckSpecific(
        address _contract,
        uint256 songIdIn,
        uint256 generationIn
    ) external view returns (uint256 _songIdOut, uint256 _generationOut, uint256 _promoPercentOut);

    // Mints a promo token using the contract wide setting
    function promoMint(address _contract, uint256 tokenId) external payable;

    // Mints a promo token using the setting that needs matching songId and generation to be accepted
    function promoMintSpecific(address _contract, uint256 tokenId) external payable;

    // Returns if a token from an address has claimed it's promo token for the contract wide reward
    function tokenClaimCheck(address _contract, uint256 tokenId)
        external
        view
        returns (bool);

    // Returns if a token from an address has claimed it's promo token for the specific reward
    function tokenClaimCheckSpecific(address _contract, uint256 tokenId)
        external
        view
        returns (bool);

    // Sets a promo claim for a contract wide reward.  Any token from an ERC721 contract gets a reward.
    function setPromo(
        address _contract,
        uint256 promoPercentOut,
        uint256 songIdOut,
        uint256 generationOut
    ) external;

    // Sets a promo claim for a ERC721J specific reward.  Any token from an ERC721J contract can get a reward based on it's song, rarity, or both.
    function setPromoSpecific(
        address _contract,
        uint256 songIdIn,
        uint256 generationIn,
        uint256 promoPercentOut,
        uint256 songIdOut,
        uint256 generationOut
    ) external;


}

