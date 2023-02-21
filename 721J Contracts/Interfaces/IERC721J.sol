// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IERC721J is IERC165 {
  
    //When a copy is minted, emits the tokenId that was used to make the copy.  To count referral points.
    event Copy(uint256 indexed tokenId);

    //Returns the contract metadata
    function contractURI() external view returns (string memory);

    //Returns the max supply of copies for a songId
    function maxSongSupply(uint256 songId) external view returns (uint256);

    //Mints a copy 
    function mintCopy(uint256 tokenId) external payable;

    //Mints a copy to a wallet address of your choice
    function mintCopyTo(uint256 tokenId, address to) external payable;

    //Mints an original using 1 piece of metadata
    function mintOriginal(string memory songURI1, uint256 maxEditions) external;

    //Mints an original using the default 3 pieces of metadata
    function mintOriginal3(
        string memory songURI1,
        string memory songURI2,
        string memory songURI3,
        uint256 maxEditions
    ) external;

    //Returns the price to mint a copy
    function mintPrice() external view returns (uint256);

    //The owner of the contract can mint copies for free and also mint custom rarity copies
    function ownerMintCopy(
        uint256 tokenId,
        uint256 songGeneration,
        address to
    ) external;

    //Returns the generation / rarity of a tokenId
    function rarityOfToken(uint256 tokenId) external view returns (uint256);

    //Returns the songId for a tokenId
    function songOfToken(uint256 tokenId) external view returns (uint256);

    //Returns the current supply of copies for a songId
    function songSupply(uint256 songId) external view returns (uint256);

    //Returns the metadata for a songId and generation
    function songURI(uint256 songId, uint256 songGeneration)
        external
        view
        returns (string memory);

    //Returns the total amount of originals created
    function totalSongs() external view returns (uint256);
    
}

