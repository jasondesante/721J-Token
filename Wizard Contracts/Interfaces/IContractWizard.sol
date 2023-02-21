// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IContractWizard is IERC165 {
  
    // Emits when a new contract is created
    event NewContract(address contractAddress, uint256 contractId);

    // Returns the contract metadata
    function contractURI() external view returns (string memory);

    // Returns the contract address for a contract id
    function contractByIndex(uint256 contractId)
        external
        view
        returns (address);

    // Creates a new contract
    function createClone(
        string memory cloneName,
        string memory cloneSymbol,
        uint256 mintPriceWei
    ) external payable returns (address);

    // Creates a new contract and pays the wizard with an ERC20 token
    function createCloneToken(
        string memory cloneName,
        string memory cloneSymbol,
        uint256 mintPriceWei,
        address token
    ) external returns (address);

    // Returns the contractId if an address can be found in the List of the Wizard
    function inCollection(address contractAddress)
        external
        view
        returns (uint256);

    // Returns the mint price in eth to create a contract
    function mintPrice() external view returns (uint256);

    // Returns the name of the contract
    function name() external view returns (string memory);

    // Returns the mint price in an ERC20 token to create a contract
    function tokenMintPrice(address token) external view returns (uint256);

    // Returns the total amount of contracts that have been minted by this Contract Wizard
    function totalSupply() external view returns (uint256);

}

