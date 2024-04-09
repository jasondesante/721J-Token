// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721JUpgradeable.sol";
import "@openzeppelin/contracts@4.7.0/proxy/Clones.sol";
import "@openzeppelin/contracts@4.7.0/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts@4.7.0/access/Ownable.sol";

import "./Interfaces/IContractWizard.sol"; // Interface Id: 0xeb4285e2

// Ape Tapes Contract Wizard 
// Jason DeSante
//
//
contract ApeTapesContractWizard is ERC165, Ownable, IContractWizard {
    address immutable tokenImplementation;

    constructor() {
        tokenImplementation = address(new ERC721J());
    }

    // Token name
    string private _name = "Ape Tapes Contract Wizard";

    // Contract ids is the total number of all the clone contracts made
    uint256 private _contractIds;

    // Mint price to create contract
    uint256 private _mintPrice = 1000000000000000000;

    // Define Contract URI
    string private _contractURI;

    // Mapping contract id with clone address
    mapping(uint256 => address) private cloneLibrary;

    // Price in wei for erc-20 address
    mapping(address => uint256) private _tokenPrice;

    // Declaring new events
    event TokenPriceSet(address indexed tokenContract, uint256 price);
    
    event ContractURIChange(string indexed oldContractURI);

    // ERC165 support
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IContractWizard).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // Returns a contract address when you enter in a contract id.
    function contractByIndex(uint256 contractId) public view override returns (address) {
        if (contractId >= _contractIds) revert TokenIndexOutOfBounds();
        return cloneLibrary[contractId];
    }

    // Returns the a number in the index if the contract is in the directory.
    function inCollection(address contractAddress)
        public
        view
        override
        returns (uint256)
    {
        uint256 contractsMintedSoFar = _contractIds;
        unchecked {
            for (uint256 i; i <= contractsMintedSoFar; ++i) {
                if (cloneLibrary[i] == contractAddress) return i;
            }
        }
        // Execution should never reach this point.
        assert(false);
        return 0;
    }

    // Creates a clone.
    function createClone(
        string calldata cloneName,
        string calldata cloneSymbol,
        uint256 mintPriceWei
    ) public payable override returns (address) {
        // Requires eth
        if (msg.value < _mintPrice) revert NotEnoughEther();
        // Creates clone
        address clone = Clones.clone(tokenImplementation);
        ERC721J(clone).initialize(cloneName, cloneSymbol, msg.sender, mintPriceWei);
        // Finds the next contract id
        uint256 contractId = _contractIds;
        // Assigns clone a contract id
        cloneLibrary[contractId] = clone;

        emit NewContract(clone, contractId);

        ++contractId;
        _contractIds = contractId;

        return clone;
    }

    // Creates a clone paying with an ERC20 token
    function createCloneToken(
        string calldata cloneName,
        string calldata cloneSymbol,
        uint256 mintPriceWei,
        address token
    ) public override returns (address) {
        // Requires token
        if (ERC20Upgradeable(token).balanceOf(msg.sender) < _tokenPrice[token])
            revert NotEnoughEther();
        // Checks if contract is approved
        if (_tokenPrice[token] == 0) revert TokenNotApproved();

        // Transfer tokens
        ERC20Upgradeable(token).transferFrom(
            msg.sender,
            owner(),
            _tokenPrice[token]
        );

        // Creates clone
        address clone = Clones.clone(tokenImplementation);
        ERC721J(clone).initialize(cloneName, cloneSymbol, msg.sender, mintPriceWei);
        // Finds the next contract id
        uint256 contractId = _contractIds;
        // Assigns clone a contract id
        cloneLibrary[contractId] = clone;

        emit NewContract(clone, contractId);

        ++contractId;
        _contractIds = contractId;
        return clone;
    }


    // Owner creates a clone.
    function ownerCreateClone(
        string calldata cloneName,
        string calldata cloneSymbol,
        uint256 mintPriceWei
    ) public onlyOwner returns (address) {
        // Creates clone
        address clone = Clones.clone(tokenImplementation);
        ERC721J(clone).initialize(cloneName, cloneSymbol, msg.sender, mintPriceWei);
        // Finds the next contract id
        uint256 contractId = _contractIds;
        // Assigns clone a contract id
        cloneLibrary[contractId] = clone;

        emit NewContract(clone, contractId);

        ++contractId;
        _contractIds = contractId;
        return clone;
    }

    // Owner adds a contract to the library.
    function ownerAddContract(
        address contractAddress
    ) public onlyOwner returns (address) {
        // Finds the next contract id
        uint256 contractId = _contractIds;
        // Assigns address a contract id
        cloneLibrary[contractId] = contractAddress;

        emit NewContract(contractAddress, contractId);

        ++contractId;
        _contractIds = contractId;

        return contractAddress;
    }

    // Returns the name of the contract
    function name() public view virtual override returns (string memory) {
        return _name;
    }
    
    // Returns contractURI internally
    function contractURI() public view virtual override returns (string memory) {
        return (_contractURI);
    }

    // Sets the contractURI
    function setContractURI(string memory uri) public virtual onlyOwner {
        emit ContractURIChange(_contractURI);

        _contractURI = uri;
    }

    // Returns the total amount of contracts made by the wizard
    function totalSupply() public view virtual override returns (uint256) {
        return _contractIds;
    }

    // Returns Mint Price
    function mintPrice() public view virtual override returns (uint256) {
        return _mintPrice;
    }

    // Sets the Mint Price in Wei
    function setMintPrice(uint256 priceWei) public virtual onlyOwner {
        _mintPrice = priceWei;
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
    function setTokenMintPrice(address token, uint256 price)
        public
        virtual
        onlyOwner
    {
        _tokenPrice[token] = price;
        emit TokenPriceSet(token, price);
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
}
//
//