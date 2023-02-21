// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./IERC721J.sol";

interface IERC721JEnumerable is IERC721J {

    //Returns an index of tokens that are set to public
    function tokenOfPublicByIndex(uint256 index)
        external
        view
        returns (uint256);

    //Returns an index of tokens with a particular songId
    function tokenOfSongByIndex(uint256 songId, uint256 index)
        external
        view
        returns (uint256);

}

