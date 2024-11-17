// SPDX-License-Identifier: MIT
// Interface for Woolball contract

pragma solidity >=0.8.28;

import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

/**
 * @title Commander Token Simple Implementation
 * @author Eyal Ron, Tomer Leicht, Ahmad Afuni
 * @notice This is the simplest implementation of Commander Token, you should inherent in order to extend it for complex use cases
 * @dev Commander Tokens is an extenntion to ERC721 with the ability to create non-transferable or non-burnable tokens.
 * @dev For this cause we add a new mechniasm enabling a token to depend on another token.
 * @dev If Token A depends on B, then if Token B is nontransferable or unburnable, so does Token A.
 * @dev if token B depedns on token A, we again call A a Commander Token (CT).
 */
interface IWoolball is IERC721 {
    /**
     * @dev Emitted when a new human name is created by a wallet.
     */
    event humanNameCreated(string name, address creator);

    /**
     * @dev Emitted when a new Artifician name is created by another name.
     */
    event humanNameCreated(string name, uint256 creatorNameID);

    /**
     * @dev Emitted when a subname is created
     */
    event subnameCreated(
        string subname,
        uint256 creatorNameID,
        uint256 subnameID
    );

    event humanVerified(uint256 nameID);

    function newHumanName(
        string calldata name,
        address creator,
        bytes32 pubkeyX,
        bytes32 pubkeyY,
        uint32 duration_in_months
    ) external payable returns (uint256);

    function newArtificialName(
        string calldata name,
        uint256 creatorNameID,
        bytes32 pubkeyX,
        bytes32 pubkeyY,
        uint32 duration_in_months
    )
        external payable returns (uint256);
}
