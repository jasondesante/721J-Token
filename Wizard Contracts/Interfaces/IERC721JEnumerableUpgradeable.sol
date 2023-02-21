// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./IERC721JUpgradeable.sol";

interface IERC721JEnumerableUpgradeable is IERC721JUpgradeable {

    // Returns an index of tokens that are set to public
    function tokenOfPublicByIndex(uint256 index)
        external
        view
        returns (uint256);

    // Returns an index of tokens with a particular songId
    function tokenOfSongByIndex(uint256 songId, uint256 index)
        external
        view
        returns (uint256);

}

