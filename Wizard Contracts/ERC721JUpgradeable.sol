// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol"; // Interface Id: 0x80ac58cd
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol"; // Interface Id: 0x150b7a02
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol"; // Interface Id: 0x5b5e139f
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol"; // Interface Id: 0x780e9d63
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Interfaces/IERC721JUpgradeable.sol"; // Interface Id: 0x75b86392
import "./Interfaces/IERC721JFullUpgradeable.sol"; // Interface Id: 0xa360e0cd
import "./Interfaces/IERC721JPromoUpgradeable.sol"; // Interface Id: 0x17bbaa28
import "./Interfaces/IERC721JEnumerableUpgradeable.sol"; // Interface Id: 0xd2ac8720

import "./Interfaces/IERC2981Upgradeable.sol"; // Interface Id: 0x2a55205a

error ApprovalCallerNotOwnerNorApproved();
error ApprovalQueryForNonexistentToken();
error ApprovalToCurrentOwner();
error BalanceQueryForZeroAddress();
error MaxCopiesReached();
error MintToZeroAddress();
error NotEnoughEther();
error OwnerIndexOutOfBounds();
error OwnerIsOperator();
error OwnerQueryForNonexistentToken();
error QueryForNonexistentToken();
error SenderNotOwner();
error TokenAlreadyMinted();
error TokenIndexOutOfBounds();
error TransferCallerNotOwnerNorApproved();
error TransferFromIncorrectOwner();
error TransferToNonERC721ReceiverImplementer();
error TransferToZeroAddress();
error URIQueryForNonexistentToken();
error URIQueryForNonexistentSong();
error TokenNotApproved();
error TokenBalanceZero();
error TokenAlreadyClaimed();
error GenerationOutOne();
error GenerationOutZero();
error SongInZero();
error NewMaxLessThanCurrentSupply();
error InvalidGeneration();
error RecycleDisabled();
error RoyaltyBPSTooHigh();

//
// Version 2 of ERC721J
// Jason DeSante
//
// Supports 1/1 original master with any edition size.
// Minting a copy requires the minter to own a copy,
// or for the token to be staked.
//
//
// New in v2: custom max supply,
// Mint price can be set, in eth and any erc-20 token.
// Rarity affected by generation of copy
// Added public mint switch (staking to the store) as an option to mint copies traditionally.
// Added recycle to burn 2 songs to mint 1. Recycling is an opt in option.
// Added promo system. Supports ERC721 tokens, and 721J support letting you set promos with rarity and songId. Each promo has it's own price multiplier.
// Added and the ability to change the max editions of a song, the name or symbol of the contract.
// Added a rarity price multiplier to make the price different for specific rarities.
// Added support for splits, each song can send it's tokens to a specified address.
// Added support for IERC-2981, and on chain royalties.
// Added 4 interfaces to represent the essential functions in 4 main pieces of the 721J
// IERC721J for the main parts, IERC721JFull for the full essentials, IERC721JPromo for the promo system, IERC721JEnumerable for the indexes
//
//
//
contract ERC721J is
    Initializable,
    ContextUpgradeable,
    ERC165Upgradeable,
    IERC721Upgradeable,
    IERC721MetadataUpgradeable,
    IERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    IERC721JUpgradeable,
    IERC721JFullUpgradeable,
    IERC721JPromoUpgradeable,
    IERC721JEnumerableUpgradeable,
    IERC2981Upgradeable
{
    function initialize(
        string memory cloneName,
        string memory cloneSymbol,
        address cloneOwner,
        uint256 cloneMintPrice
    ) public virtual initializer {
        __ERC721J_init(cloneName, cloneSymbol, cloneOwner, cloneMintPrice);
    }

    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;
    
    // _tokenIds and _songIds for keeping track of the ongoing total tokenids, and total songids
    uint256 private _tokenIds;
    uint256 private _songIds;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Define the baseURI
    string private _baseURI;

    // Define mint price
    uint256 private _mintPrice;

    // Define royalty BPS
    uint256 private _royaltyBPS;

    // Define Contract URI
    string private _contractURI;

    // Define toggle recycle
    bool private _enableRecycle;

    struct tokenInfo {
        uint128 song;
        uint128 generation;
    }

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Mapping for song URIs. Takes songId then songGeneration combined as a number with a string for the URI.
    mapping(uint256 => string) private _songURIs;

    // Mapping of songIds to counters of copies minted for each song
    mapping(uint256 => uint256) private _songSerials;

    // Mapping for the extra info to each tokenId
    mapping(uint256 => tokenInfo) private _tokenIdInfo;

    // Mapping for the max songs. Takes songId then max amount of editions for that song.
    mapping(uint256 => uint256) private _maxEditions;

    // Mapping for erc-20 token addresses and their price in wei
    mapping(address => uint256) private _tokenPrice;

    // True or false for a tokenId if public mint (staking) is on for it
    mapping(uint256 => bool) private _publicMint;

    // Mapping for song splits. Takes songId with the address.
    mapping(uint256 => address payable) private _songSplits;

    // Mapping for rarity multipliers. Takes generation number with the multiplier percent number.
    mapping(uint256 => uint256) private _rarityMultipliers;

    // Declaring new events

    event TokenPriceSet(address indexed tokenContract, uint256 price);

    event NewMax(uint256 indexed songId, uint256 maxEditions);

    event NewSongURI(uint256 indexed songId, uint256 indexed generation);

    event NameChange(string indexed oldName);

    event SymbolChange(string indexed oldSymbol);

    event BaseURIChange(string indexed oldBaseURI);

    event ContractURIChange(string indexed oldContractURI);

    event TogglePublic(uint256 indexed tokenId);

    event NewSplit(uint256 indexed songId, address payable splitAddress);

    event NewMultiplier(uint256 indexed generation, uint256 multiplierPercent);

    // Initializes the contract and sets variables
    function __ERC721J_init(
        string memory name_,
        string memory symbol_,
        address owner,
        uint256 mintPrice_
    ) internal onlyInitializing {
        __ERC721J_init_unchained(name_, symbol_, owner, mintPrice_);
    }

    function __ERC721J_init_unchained(
        string memory name_,
        string memory symbol_,
        address owner,
        uint256 mintPrice_
    ) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
        _transferOwnership(owner);
        _mintPrice = mintPrice_;
    }

    //
    // From erc721enumerable
    //
    // Function returns the total supply of tokens minted by the contract
    function totalSupply() public view virtual override returns (uint256) {
        return _tokenIds;
    }

    function tokenByIndex(uint256 index)
        public
        view
        override
        returns (uint256)
    {
        if (index > _tokenIds - 1) revert TokenIndexOutOfBounds();
        return index + 1;
    }

    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        override
        returns (uint256)
    {
        if (index > balanceOf(owner)) revert OwnerIndexOutOfBounds();
        uint256 numMintedSoFar = _tokenIds;
        uint256 tokenIdsIdx;
        address currOwnershipAddr;
        unchecked {
            for (uint256 i; i <= numMintedSoFar; ++i) {
                address ownership = _owners[i];
                if (ownership != address(0)) {
                    currOwnershipAddr = ownership;
                }
                if (currOwnershipAddr == owner && ownership != address(0)) {
                    if (tokenIdsIdx == index) {
                        return i;
                    }
                    ++tokenIdsIdx;
                }
            }
        }
        // Execution should never reach this point.
        assert(false);
        return 0;
    }

    // Returns the serial # of a songId
    function tokenOfSongByIndex(uint256 songId, uint256 index)
        public
        view
        override
        returns (uint256)
    {
        if (index > _songSerials[songId]) revert OwnerIndexOutOfBounds();
        uint256 numMintedSoFar = _tokenIds;
        uint256 tokenIdsIdx;
        uint256 currSong;
        unchecked {
            for (uint256 i; i <= numMintedSoFar; ++i) {
                uint256 song = _tokenIdInfo[i].song;
                if (song != 0) {
                    currSong = song;
                }
                if (currSong == songId && _owners[i] != address(0)) {
                    if (tokenIdsIdx == index) {
                        return i;
                    }
                    ++tokenIdsIdx;
                }
            }
        }
        // Execution should never reach this point.
        assert(false);
        return 0;
    }

    // Returns every song that has public mint set to true
    function tokenOfPublicByIndex(uint256 index)
        public
        view
        override
        returns (uint256)
    {
        uint256 numMintedSoFar = _tokenIds;
        if (index > numMintedSoFar) revert OwnerIndexOutOfBounds();

        uint256 tokenIdsIdx;
        unchecked {
            for (uint256 i; i <= numMintedSoFar; ++i) {
                bool _public = _publicMint[i];
                uint256 _song = _tokenIdInfo[i].song;
                if (
                    _public != false &&
                    _owners[i] != address(0) &&
                    _songSerials[_song] != _maxEditions[_song]
                ) {
                    if (tokenIdsIdx == index) {
                        return i;
                    }
                    ++tokenIdsIdx;
                }
            }
        }
        // Execution should never reach this point.
        assert(false);
        return 0;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721ReceiverUpgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            interfaceId == type(IERC721EnumerableUpgradeable).interfaceId ||
            interfaceId == type(IERC721JUpgradeable).interfaceId ||
            interfaceId == type(IERC721JFullUpgradeable).interfaceId ||
            interfaceId == type(IERC721JPromoUpgradeable).interfaceId ||
            interfaceId == type(IERC721JEnumerableUpgradeable).interfaceId ||
            interfaceId == type(IERC2981Upgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (owner == address(0)) revert BalanceQueryForZeroAddress();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert OwnerQueryForNonexistentToken();
        return owner;
    }

    // Returns the name for the contract
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    // Sets the name
    function setName(string memory newName) public virtual onlyOwner {
        emit NameChange(_name);

        _name = newName;
    }

    // Returns the symbol for the contract
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    // Sets the symbol
    function setSymbol(string memory newSymbol) public virtual onlyOwner {
        emit SymbolChange(_symbol);

        _symbol = newSymbol;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        uint256 songId = _tokenIdInfo[tokenId].song;
        uint256 songGeneration = _tokenIdInfo[tokenId].generation;
        string memory _tokenURI;
        // Shows different uri depending on serial number
        _tokenURI = _songURIs[(songId * (10**18)) + songGeneration];
        for (uint256 i; i <= songGeneration && bytes(_tokenURI).length == 0; ++i) {
            _tokenURI = _songURIs[(songId * (10**18)) + songGeneration - i];
        }

        // Set baseURI
        string memory base = _baseURI;
        // Concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        } else {
            return "";
        }
    }

    //
    //
    // URI Section
    //
    //

    // Returns baseURI internally
    function baseURI() public view virtual returns (string memory) {
        return _baseURI;
    }

    // Sets the baseURI
    function setBaseURI(string memory base) public virtual onlyOwner {
        emit BaseURIChange(_baseURI);

        _baseURI = base;
    }

    // Returns contractURI internally
    function contractURI()
        public
        view
        virtual
        override
        returns (string memory)
    {
        // Set baseURI
        string memory base = _baseURI;
        // Concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_contractURI).length > 0) {
            return string(abi.encodePacked(base, _contractURI));
        } else {
            return "";
        }
    }

    // Sets the contractURI
    function setContractURI(string memory uri) public virtual onlyOwner {
        emit ContractURIChange(_contractURI);

        _contractURI = uri;
    }

    // Sets the songURIs when minting a new song
    function _setSongURI(uint256 songId, string memory songURI1)
        internal
        virtual
    {
        if (songId > _songIds) revert URIQueryForNonexistentSong();

        _songURIs[(songId * (10**18)) + 1] = songURI1;

        emit NewSongURI(songId, 1);
    }

    // Sets the songURIs when minting a new song
    function _setSongURI3(
        uint256 songId,
        string memory songURI1,
        string memory songURI2,
        string memory songURI3
    ) internal virtual {
        if (songId > _songIds) revert URIQueryForNonexistentSong();

        _songURIs[(songId * (10**18)) + 1] = songURI1;
        _songURIs[(songId * (10**18)) + 2] = songURI2;
        _songURIs[(songId * (10**18)) + 3] = songURI3;

        emit NewSongURI(songId, 3);
    }

    // Changes the songURI for one generation of a song, when given the songId and songGeneration
    function setSongURI(
        uint256 songId,
        uint256 songGeneration,
        string memory _songURI
    ) public virtual onlyOwner {
        if (songId > _songIds) revert URIQueryForNonexistentSong();

        _songURIs[(songId * (10**18)) + songGeneration] = _songURI;

        emit NewSongURI(songId, songGeneration);
    }

    // Changes an array of songURIs when given an array of generations and songURIs
    function setSongURIs(
        uint256 songId,
        uint256[] memory songGenerations,
        string[] memory songURIs
    ) public virtual onlyOwner {
        uint256 length = songGenerations.length;
        if (songId > _songIds) revert URIQueryForNonexistentSong();

        for (uint256 i; i < length; ++i) {
            _songURIs[(songId * (10**18)) + songGenerations[i]] = songURIs[i];
            emit NewSongURI(songId, songGenerations[i]);
        }
    }

    // Changes an array of many songURIs
    function setManySongURIs(
        uint256[] memory songIds,
        uint256[] memory songGenerations,
        string[] memory songURIs
    ) public virtual onlyOwner {
        uint256 length = songGenerations.length;

        for (uint256 i; i < length; ++i) {
            if (songIds[i] > _songIds) revert URIQueryForNonexistentSong();
            _songURIs[(songIds[i] * (10**18)) + songGenerations[i]] = songURIs[
                i
            ];
            emit NewSongURI(songIds[i], songGenerations[i]);
        }
    }

    //
    // ERC721 Meat and Potatoes Section
    //

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        if (to == owner) revert ApprovalToCurrentOwner();

        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender())) {
            revert ApprovalCallerNotOwnerNorApproved();
        }

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    //
    // Transfer Section
    //
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            revert TransferCallerNotOwnerNorApproved();
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            revert TransferCallerNotOwnerNorApproved();
        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, _data)) {
            revert TransferToNonERC721ReceiverImplementer();
        }
    }

    //
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        returns (bool)
    {
        if (!_exists(tokenId)) revert QueryForNonexistentToken();
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    //
    // Minting Section!
    //

    // Returns Mint Price
    function mintPrice() public view virtual override returns (uint256) {
        return _mintPrice;
    }

    // Sets the Mint Price in Wei
    function setMintPrice(uint256 priceWei) public virtual onlyOwner {
        _mintPrice = priceWei;
    }

    // Returns status of public mint for tokenId
    function publicMint(uint256 tokenId) public view virtual override returns (bool) {
        return _publicMint[tokenId];
    }

    // Toggles Public Mint for Token Id
    function togglePublicMint(uint256 tokenId) public virtual {
        if (!_isApprovedOrOwner(_msgSender(), tokenId)) revert SenderNotOwner();
        _publicMint[tokenId] = !_publicMint[tokenId];
        emit TogglePublic(tokenId);
    }

    //
    // Toggles an array of Token Ids public mint status
    function togglePublicMints(uint256[] memory tokenIds) public virtual {
        uint256 length = tokenIds.length;
        for (uint256 i; i < length; ++i) {
            togglePublicMint(tokenIds[i]);
        }
    }

    // Returns Token Mint Price
    function tokenMintPrice(address token)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _tokenPrice[token];
    }

    // Sets the Token Mint Price in Wei
    function setTokenMintPrice(address token, uint256 priceWei)
        public
        virtual
        onlyOwner
    {
        _tokenPrice[token] = priceWei;
        emit TokenPriceSet(token, priceWei);
    }

    // Changes the max editions for a song
    function setMaxEditions(uint256 songId, uint256 maxEditions)
        public
        virtual
        onlyOwner
    {
        if (_songSerials[songId] > maxEditions) {
            revert NewMaxLessThanCurrentSupply();
        }

        _maxEditions[songId] = maxEditions;
        emit NewMax(songId, maxEditions);
    }

    // Returns if recycle minting has been enabled
    function recycleEnabled() public view virtual returns (bool) {
        return _enableRecycle;
    }

    // Toggles recycle mint
    function toggleRecycleMint() public virtual onlyOwner {
        _enableRecycle = !_enableRecycle;
    }

    // Returns the address to pay out for a particular song id
    function splits(uint256 songId)
        public
        view
        virtual
        returns (address payable)
    {
        return _songSplits[songId];
    }

    // Sets the split address for a song id
    function setSplit(uint256 songId, address payable splitAddress)
        public
        virtual
        onlyOwner
    {
        _songSplits[songId] = splitAddress;
        emit NewSplit(songId, splitAddress);
    }

    // Returns the percent price multiplier for a rarity
    function rarityMultiplier(uint256 generation)
        public
        view
        virtual
        override
        returns (uint256 multiplierPercent)
    {
        return _rarityMultipliers[generation];
    }

    // Sets the price multiplier for a rarity
    function setRarityMultiplier(uint256 generation, uint256 multiplierPercent)
        public
        virtual
        onlyOwner
    {
        _rarityMultipliers[generation] = multiplierPercent;
        emit NewMultiplier(generation, multiplierPercent);
    }

    // Returns the royalty info.  From ERC2981.  Takes tokenId and price and returns the receiver address and royalty amount.
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        public
        view
        virtual
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        uint256 songId = _tokenIdInfo[tokenId].song;
        if (address(_songSplits[songId]) != address(0)) {
            receiver = address(_songSplits[songId]);
        } else {
            receiver = owner();
        }
        royaltyAmount = (salePrice * _royaltyBPS) / 10000;
        return (receiver, royaltyAmount);
    }

    // Returns the royalty basis points
    function royaltyBPS() public view virtual returns (uint256) {
        return _royaltyBPS;
    }

    // Sets the royalty basis points
    function setRoyalty(uint256 royaltyBPS_) public virtual onlyOwner {
        if (royaltyBPS_ > 10000) revert RoyaltyBPSTooHigh();
        _royaltyBPS = royaltyBPS_;
    }

    // Sets a few variables you would want to with a new contract
    function setVariables2(
        string memory baseURI_,
        string memory contractURI_,
        uint256 royaltyBPS_
    ) public virtual onlyOwner {
        setBaseURI(baseURI_);
        setContractURI(contractURI_);
        setRoyalty(royaltyBPS_);
    } 

    //
    //
    //
    //
    // Mint Master token and set 1 piece of metadata
    function mintOriginal(string memory songURI1, uint256 maxEditions)
        public
        override
        onlyOwner
    {
        // Updates the count of total tokenids and songids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;
        uint256 songId = _songIds;
        ++songId;
        _songIds = songId;

        // Updates the count of how many of a particular song have been made
        _songSerials[songId] = 1;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(1);
        // Sets the max supply for the song
        _maxEditions[songId] = maxEditions;

        _safeMint(msg.sender, id);
        _setSongURI(songId, songURI1);
    }

    // Mint Master token and set 1 piece of metadata and a split address
    function mintOriginalSplit(
        string memory songURI1,
        uint256 maxEditions,
        address payable splitAddress
    ) public onlyOwner {
        // Updates the count of total tokenids and songids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;
        uint256 songId = _songIds;
        ++songId;
        _songIds = songId;

        // Updates the count of how many of a particular song have been made
        _songSerials[songId] = 1;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(1);
        // Sets the max supply for the song
        _maxEditions[songId] = maxEditions;

        // Sets the song split
        _songSplits[songId] = splitAddress;
        emit NewSplit(songId, splitAddress);

        _safeMint(msg.sender, id);
        _setSongURI(songId, songURI1);
    }

    // Intended method.  Mint Master token and set 3 pieces of metadata.
    function mintOriginal3(
        string memory songURI1,
        string memory songURI2,
        string memory songURI3,
        uint256 maxEditions
    ) public override onlyOwner {
        // Updates the count of total tokenids and songids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;
        uint256 songId = _songIds;
        ++songId;
        _songIds = songId;

        // Updates the count of how many of a particular song have been made
        _songSerials[songId] = 1;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(1);
        // Sets the max supply for the song
        _maxEditions[songId] = maxEditions;

        _safeMint(msg.sender, id);
        _setSongURI3(songId, songURI1, songURI2, songURI3);
    }

    // Mint Master token and set 3 pieces of metadata and a split address.
    function mintOriginal3Split(
        string memory songURI1,
        string memory songURI2,
        string memory songURI3,
        uint256 maxEditions,
        address payable splitAddress
    ) public onlyOwner {
        // Updates the count of total tokenids and songids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;
        uint256 songId = _songIds;
        ++songId;
        _songIds = songId;

        // Updates the count of how many of a particular song have been made
        _songSerials[songId] = 1;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(1);
        // Sets the max supply for the song
        _maxEditions[songId] = maxEditions;

        // Sets the song split
        _songSplits[songId] = splitAddress;
        emit NewSplit(songId, splitAddress);

        _safeMint(msg.sender, id);
        _setSongURI3(songId, songURI1, songURI2, songURI3);
    }

    function ownerMintCopy(
        uint256 tokenId,
        uint256 songGeneration,
        address to
    ) public override onlyOwner {
        // Requires the sender to have the tokenId in their wallet
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            if (_publicMint[tokenId] == false) revert SenderNotOwner();

        if (songGeneration < 2) {
            revert InvalidGeneration();
        }
        // Gets the songId from the tokenId
        uint256 songId = _tokenIdInfo[tokenId].song;
        uint256 songSerial = _songSerials[songId];
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[songId]) revert MaxCopiesReached();

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[songId] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(songGeneration);

        emit Copy(tokenId);

        _safeMintCopy(ownerOf(tokenId), to, id);
    }

    // Mints a copy to the owner's wallet
    function mintCopy(uint256 tokenId) public payable override {
        // Requires the sender to have the tokenId in their wallet
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            if (_publicMint[tokenId] == false) revert SenderNotOwner();
        // Gets the songId from the tokenId
        uint256 songId = _tokenIdInfo[tokenId].song;
        uint256 songSerial = _songSerials[songId];
        uint256 songGeneration = _tokenIdInfo[tokenId].generation;
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[songId]) revert MaxCopiesReached();
        // Checks rarity multiplier percent
        uint256 multPc = 100;
        if (_rarityMultipliers[songGeneration] > 0)
            multPc = _rarityMultipliers[songGeneration];
        // Requires eth
        if (msg.value < (_mintPrice * multPc) / 100) revert NotEnoughEther();
        // Transfer eth
        if (address(_songSplits[songId]) != address(0)) {
            (bool success, ) = _songSplits[songId].call{value: msg.value}("");
            require(success, "Failed to send Ether");
        }

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[songId] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(songGeneration + 1);

        emit Copy(tokenId);

        _safeMintCopy(ownerOf(tokenId), msg.sender, id);
    }

    // Mints a copy to the address entered
    function mintCopyTo(uint256 tokenId, address to) public payable override {
        // Requires the sender to have the tokenId in their wallet
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            if (_publicMint[tokenId] == false) revert SenderNotOwner();
        // Gets the songId from the tokenId
        uint256 songId = _tokenIdInfo[tokenId].song;
        uint256 songSerial = _songSerials[songId];
        uint256 songGeneration = _tokenIdInfo[tokenId].generation;
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[songId]) revert MaxCopiesReached();
        // Checks rarity multiplier percent
        uint256 multPc = 100;
        if (_rarityMultipliers[songGeneration] > 0)
            multPc = _rarityMultipliers[songGeneration];
        // Requires eth
        if (msg.value < (_mintPrice * multPc) / 100) revert NotEnoughEther();
        // Transfer eth
        if (address(_songSplits[songId]) != address(0)) {
            (bool success, ) = _songSplits[songId].call{value: msg.value}("");
            require(success, "Failed to send Ether");
        }

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[songId] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(songGeneration + 1);

        emit Copy(tokenId);

        _safeMintCopy(ownerOf(tokenId), to, id);
    }

    // Mints a copy with an erc-20 token as payment
    function mintCopyToken(uint256 tokenId, address token) public override {
        // Checks if contract is approved
        if (_tokenPrice[token] == 0) revert TokenNotApproved();
        // Requires the sender to have the tokenId in their wallet
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            if (_publicMint[tokenId] == false) revert SenderNotOwner();
        // Gets the songId from the tokenId
        uint256 songId = _tokenIdInfo[tokenId].song;
        uint256 songSerial = _songSerials[songId];
        uint256 songGeneration = _tokenIdInfo[tokenId].generation;
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[songId]) revert MaxCopiesReached();
        // Checks rarity multiplier percent
        uint256 multPc = 100;
        if (_rarityMultipliers[songGeneration] > 0)
            multPc = _rarityMultipliers[songGeneration];
        uint256 rarityPrice = (_tokenPrice[token] * multPc) / 100;
        // Requires token
        if (ERC20Upgradeable(token).balanceOf(msg.sender) < rarityPrice)
            revert NotEnoughEther();
        // Transfer tokens
        if (address(_songSplits[songId]) != address(0)) {
            ERC20Upgradeable(token).transferFrom(
                msg.sender,
                _songSplits[songId],
                rarityPrice
            );
        } else {
            ERC20Upgradeable(token).transferFrom(
                msg.sender,
                owner(),
                rarityPrice
            );
        }

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[songId] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(songGeneration + 1);

        emit Copy(tokenId);

        _safeMintCopy(ownerOf(tokenId), msg.sender, id);
    }

    // Mints a copy with an erc-20 token as payment to the address entered
    function mintCopyTokenTo(
        uint256 tokenId,
        address token,
        address to
    ) public override {
        // Checks if contract is approved
        if (_tokenPrice[token] == 0) revert TokenNotApproved();
        // Requires the sender to have the tokenId in their wallet
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            if (_publicMint[tokenId] == false) revert SenderNotOwner();
        // Gets the songId from the tokenId
        uint256 songId = _tokenIdInfo[tokenId].song;
        uint256 songSerial = _songSerials[songId];
        uint256 songGeneration = _tokenIdInfo[tokenId].generation;
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[songId]) revert MaxCopiesReached();
        // Checks rarity multiplier percent
        uint256 multPc = 100;
        if (_rarityMultipliers[songGeneration] > 0)
            multPc = _rarityMultipliers[songGeneration];
        uint256 rarityPrice = (_tokenPrice[token] * multPc) / 100;
        // Requires token
        if (ERC20Upgradeable(token).balanceOf(msg.sender) < rarityPrice)
            revert NotEnoughEther();
        // Transfer tokens
        if (address(_songSplits[songId]) != address(0)) {
            ERC20Upgradeable(token).transferFrom(
                msg.sender,
                _songSplits[songId],
                rarityPrice
            );
        } else {
            ERC20Upgradeable(token).transferFrom(
                msg.sender,
                owner(),
                rarityPrice
            );
        }

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[songId] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(songGeneration + 1);

        emit Copy(tokenId);

        _safeMintCopy(ownerOf(tokenId), to, id);
    }

    function recycleMint(
        uint256 mintTokenId,
        uint256 burnTokenId1,
        uint256 burnTokenId2
    ) public override {
        if (!_isApprovedOrOwner(_msgSender(), burnTokenId1))
            revert SenderNotOwner();
        if (!_isApprovedOrOwner(_msgSender(), burnTokenId2))
            revert SenderNotOwner();

        // Requires the sender to have the tokenId in their wallet
        if (!_isApprovedOrOwner(_msgSender(), mintTokenId))
            if (_publicMint[mintTokenId] == false) revert SenderNotOwner();

        // Checks if recycling is allowed
        if (_enableRecycle != true) {
            revert RecycleDisabled();
        }

        // Gets the songId from the tokenId
        uint256 songId = _tokenIdInfo[mintTokenId].song;
        uint256 songSerial = _songSerials[songId];
        uint256 songGeneration = _tokenIdInfo[mintTokenId].generation;
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[songId]) revert MaxCopiesReached();

        // Burns tokens
        _balances[msg.sender] -= 2;
        _burn(burnTokenId1);
        _burn(burnTokenId2);

        uint256 burnSongId1 = _tokenIdInfo[burnTokenId1].song;
        uint256 burnSongId2 = _tokenIdInfo[burnTokenId2].song;
        // If either burn tokens are the same songId as the token you're minting,
        // it updates the memory songSerial.  If not it updates storage.
        if (burnSongId1 == burnSongId2 && burnSongId1 != songId) {
            _songSerials[burnSongId1] -= 2;
        } else {
            if (burnSongId1 == songId) {
                --songSerial;
            } else {
                --_songSerials[burnSongId1];
            }
            if (burnSongId2 == songId) {
                --songSerial;
            } else {
                --_songSerials[burnSongId2];
            }
        }

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[songId] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(songId);
        _tokenIdInfo[id].generation = uint128(songGeneration + 1);

        emit Copy(mintTokenId);
        emit Recycle(id, _msgSender());

        _safeMintCopy(ownerOf(mintTokenId), msg.sender, id);
    }

    //
    //
    //
    //

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMintCopy(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        _safeMintCopy(from, to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        if (!_checkOnERC721Received(address(0), to, tokenId, _data)) {
            revert TransferToNonERC721ReceiverImplementer();
        }
    }

    function _safeMintCopy(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mintCopy(from, to, tokenId);
        if (!_checkOnERC721Received(address(0), to, tokenId, _data)) {
            revert TransferToNonERC721ReceiverImplementer();
        }
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        if (to == address(0)) revert MintToZeroAddress();
        if (_exists(tokenId)) revert TokenAlreadyMinted();

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _mintCopy(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        if (to == address(0)) revert MintToZeroAddress();
        if (_exists(tokenId)) revert TokenAlreadyMinted();

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    //
    //
    //
    //
    // Burn function
    function _burn(uint256 tokenId) internal virtual {
        // Clear approvals
        _approve(address(0), tokenId);

        delete _owners[tokenId];

        emit Transfer(msg.sender, address(0), tokenId);
    }

    //
    // More ERC721 Functions Meat and Potatoes style Section
    //

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        if (ownerOf(tokenId) != from) revert TransferFromIncorrectOwner();
        if (to == address(0)) revert TransferToZeroAddress();

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        if (owner == operator) revert OwnerIsOperator();
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    //
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try
                IERC721ReceiverUpgradeable(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return
                    retval ==
                    IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    //
    // Other Functions Section
    //

    // Function returns how many different songs have been created
    function totalSongs() public view virtual override returns (uint256) {
        return _songIds;
    }

    // Function returns what song a certain tokenid is
    function songOfToken(uint256 tokenId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _tokenIdInfo[tokenId].song;
    }

    // Function returns what generation rarity a certain tokenid is
    function rarityOfToken(uint256 tokenId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _tokenIdInfo[tokenId].generation;
    }

    // Function returns how many of a song are minted
    function songSupply(uint256 songId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _songSerials[songId];
    }

    // Function returns max of a song to be minted
    function maxSongSupply(uint256 songId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _maxEditions[songId];
    }

    // Returns a songURI, when given the songId and songGeneration
    function songURI(uint256 songId, uint256 songGeneration)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (songId > _songIds) revert URIQueryForNonexistentToken();
        string memory _songURI;

        _songURI = _songURIs[(songId * (10**18)) + songGeneration];
        // If that rarity does not have unique metadata, it counts down until it finds one.
        for (uint256 i; i <= songGeneration && bytes(_songURI).length == 0; ++i) {
            _songURI = _songURIs[(songId * (10**18)) + songGeneration - i];
        }

        string memory base = _baseURI;
        return
            bytes(base).length > 0
                ? string(abi.encodePacked(base, _songURI))
                : "";
    }

    // Function to withdraw all Ether from this contract.
    function withdraw() public onlyOwner {
        uint256 amount = address(this).balance;
        // Payable address can receive Ether
        address payable owner;
        owner = payable(msg.sender);
        // Send all Ether to owner
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    //
    //
    // Promo Section
    //
    //
    // Mappings
    //
    // Address to SongOut.  For ERC721
    mapping(address => uint256) private _addressClaim;
    // Address to SongIn to SongOut. For ERC721J
    mapping(address => mapping(uint256 => uint256))
        private _addressClaimSpecific;

    //
    // Address to TokenId to bool
    mapping(address => mapping(uint256 => bool)) private _tokenClaim;
    // Address to TokenId to bool
    mapping(address => mapping(uint256 => bool)) private _tokenClaimSpecific;

    //
    // Set Functions
    //
    // For normal ERC721
    function setPromo(
        address _contract,
        uint256 promoPercentOut,
        uint256 songIdOut,
        uint256 generationOut
    ) public override onlyOwner {
        if (generationOut == 1) revert GenerationOutOne();

        uint256 _songOut = (promoPercentOut * (10**36)) +
            (songIdOut * (10**18)) +
            generationOut;

        _addressClaim[_contract] = _songOut;

        emit SetPromo(_contract, 0, _songOut);
    }

    // For ERC721J
    function setPromoSpecific(
        address _contract,
        uint256 songIdIn,
        uint256 generationIn,
        uint256 promoPercentOut,
        uint256 songIdOut,
        uint256 generationOut
    ) public override onlyOwner {
        if (generationOut == 1) revert GenerationOutOne();
        if (songIdIn == 0 && generationIn == 0) revert SongInZero();

        uint256 _songIn = (songIdIn * (10**18)) + generationIn;
        uint256 _songOut = (promoPercentOut * (10**36)) +
            (songIdOut * (10**18)) +
            generationOut;

        _addressClaimSpecific[_contract][_songIn] = _songOut;

        emit SetPromo(_contract, _songIn, _songOut);
    }

    //
    // Read Functions
    //
    // Checks if a contract address is whitelisted
    function promoCheck(address _contract)
        public
        view
        virtual
        override
        returns (
            uint256 _songIdOut,
            uint256 _generationOut,
            uint256 _promoPercentOut
        )
    {
        uint256 _songOut = _addressClaim[_contract];

        _songIdOut = (_songOut / (10**18)) % (10**18);
        _generationOut = _songOut % (10**18);
        _promoPercentOut = _songOut / (10**36);
    }

    //
    // For ERC721J. Checks if a contract address, with song and rarity, is whitelisted
    function promoCheckSpecific(
        address _contract,
        uint256 songIdIn,
        uint256 generationIn
    )
        public
        view
        virtual
        override
        returns (
            uint256 _songIdOut,
            uint256 _generationOut,
            uint256 _promoPercentOut
        )
    {
        uint256 _songIn = (songIdIn * (10**18)) + generationIn;

        uint256 _songOut = _addressClaimSpecific[_contract][_songIn];

        _songIdOut = (_songOut / (10**18)) % (10**18);
        _generationOut = _songOut % (10**18);
        _promoPercentOut = _songOut / (10**36);
    }

    //
    // Checks if a token from a contract has been claimed through the normal contract wide whitelist.
    function tokenClaimCheck(address _contract, uint256 tokenId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _tokenClaim[_contract][tokenId];
    }

    //
    // Checks if a token from a contract has been claimed through the ERC721J specific whitelist.
    function tokenClaimCheckSpecific(address _contract, uint256 tokenId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _tokenClaimSpecific[_contract][tokenId];
    }

    //
    // Minting Functions
    //

    function payPromo(uint256 _songOut, uint256 _songIdOut) internal {
        uint256 _promoPercentOut = _songOut / (10**36);

        // Requires eth
        if (msg.value < (_mintPrice * _promoPercentOut) / 100)
            revert NotEnoughEther();
        // Transfer eth
        if (
            _promoPercentOut != 0 &&
            address(_songSplits[_songIdOut]) != address(0)
        ) {
            (bool success, ) = _songSplits[_songIdOut].call{value: msg.value}(
                ""
            );
            require(success, "Failed to send Ether");
        }
    }

    // Internal shared function
    function _promoMint (address _contract, uint256 _songIn, uint256 tokenId) internal virtual {

        // Grabs songOut for the contract, and gets the songIdOut and generationOut from it
        uint256 _songOut = _addressClaimSpecific[_contract][_songIn];
        uint256 _songIdOut = (_songOut / (10**18)) % (10**18);
        uint256 _generationOut = _songOut % (10**18);
        // GenerationOut being zero means you can't claim
        if (_generationOut == 0) revert GenerationOutZero();

        // Sets songId to the most recent song if songIdOut is 0
        if (_songIdOut == 0) _songIdOut = _songIds;
        //

        uint256 songSerial = _songSerials[_songIdOut];
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[_songIdOut]) revert MaxCopiesReached();

        // Sends Eth
        payPromo(_songOut, _songIdOut);

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[_songIdOut] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(_songIdOut);
        _tokenIdInfo[id].generation = uint128(_generationOut);

        _tokenClaimSpecific[_contract][tokenId] = true;

        _safeMintCopy(owner(), msg.sender, id);

    }


    // Promo mint is for ERC721 tokens
    function promoMint(address _contract, uint256 tokenId)
        public
        payable
        override
    {
        // Sets contract address as external nft
        ERC721J _claimContract = ERC721J(_contract);
        // Checks if the token has been claimed
        if (_tokenClaim[_contract][tokenId] != false)
            revert TokenAlreadyClaimed();
        // Checks if msg.sender is the owner of the token from the contract
        if (_claimContract.ownerOf(tokenId) != msg.sender)
            revert SenderNotOwner();
        // Grabs songOut for the contract, and gets the songIdOut and generationOut from it
        uint256 _songOut = _addressClaim[_contract];
        uint256 _songIdOut = (_songOut / (10**18)) % (10**18);
        uint256 _generationOut = _songOut % (10**18);
        // GenerationOut being zero means you can't claim
        if (_generationOut == 0) revert GenerationOutZero();

        // Sets songId to the most recent song if songIdOut is 0
        if (_songIdOut == 0) _songIdOut = _songIds;
        //

        uint256 songSerial = _songSerials[_songIdOut];
        // Requires the song to not be sold out
        if (songSerial >= _maxEditions[_songIdOut]) revert MaxCopiesReached();

        // Sends Eth
        payPromo(_songOut, _songIdOut);

        // Updates the count of total tokenids
        uint256 id = _tokenIds;
        ++id;
        _tokenIds = id;

        // Updates the count of how many of a particular song have been made
        ++songSerial;
        _songSerials[_songIdOut] = songSerial;
        // Makes it easy to look up the song or gen of a tokenid
        _tokenIdInfo[id].song = uint128(_songIdOut);
        _tokenIdInfo[id].generation = uint128(_generationOut);

        _tokenClaim[_contract][tokenId] = true;

        _safeMintCopy(owner(), msg.sender, id);
    }

    //
    // Promo mint specific is for ERC721J tokens
    function promoMintSpecific(address _contract, uint256 tokenId)
        public
        payable
        override
    {
        // Sets contract address as external nft
        ERC721J _claimContract = ERC721J(_contract);
        // Checks if the token has been claimed
        if (_tokenClaimSpecific[_contract][tokenId] != false)
            revert TokenAlreadyClaimed();
        // Checks if msg.sender is the owner of the token from the contract
        if (_claimContract.ownerOf(tokenId) != msg.sender)
            revert SenderNotOwner();
        // Gets songId and generation of token from old contract
        uint256 _songIdIn = _claimContract.songOfToken(tokenId);
        uint256 _generationIn = _claimContract.rarityOfToken(tokenId);
        uint256 _songIn = (_songIdIn * (10**18)) + _generationIn;
        
        _promoMint(_contract, _songIn, tokenId);
    }

    //
    // Promo mint song is for ERC721J tokens to claim a song specific reward
    function promoMintSong(address _contract, uint256 tokenId)
        public
        payable
    {
        // Sets contract address as external nft
        ERC721J _claimContract = ERC721J(_contract);
        // Checks if the token has been claimed
        if (_tokenClaimSpecific[_contract][tokenId] != false)
            revert TokenAlreadyClaimed();
        // Checks if msg.sender is the owner of the token from the contract
        if (_claimContract.ownerOf(tokenId) != msg.sender)
            revert SenderNotOwner();
        // Gets songId of token from old contract
        uint256 _songIdIn = _claimContract.songOfToken(tokenId);
        uint256 _songIn = _songIdIn * (10**18);
        
        _promoMint(_contract, _songIn, tokenId);
    }

    //
    // Promo mint rarity is for ERC721J tokens to claim a rarity specific reward
    function promoMintRarity(address _contract, uint256 tokenId)
        public
        payable
    {
        // Sets contract address as external nft
        ERC721J _claimContract = ERC721J(_contract);
        // Checks if the token has been claimed
        if (_tokenClaimSpecific[_contract][tokenId] != false)
            revert TokenAlreadyClaimed();
        // Checks if msg.sender is the owner of the token from the contract
        if (_claimContract.ownerOf(tokenId) != msg.sender)
            revert SenderNotOwner();
        // Gets generation of token from old contract
        uint256 _generationIn = _claimContract.rarityOfToken(tokenId);
        uint256 _songIn = _generationIn;
        
        _promoMint(_contract, _songIn, tokenId);
    }
    //
    //
    //
}
