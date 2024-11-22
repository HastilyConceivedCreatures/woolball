// contracts/Woolball.sol
// SPDX-License-Identifier: MIT

pragma solidity >=0.8.28;

import "./StringUtils.sol";
import "./interfaces/IWoolball.sol";
import {IWoolballErrors} from "./interfaces/IWoolballErrors.sol";
import "./interfaces/INamePricing.sol";
import {IhumanVerifier} from "./interfaces/IhumanVerifier.sol";
import "./HumanVerifierCertificate.sol";

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";


/**
 * @dev Woolball Registry contract
 * @dev A name system for humans only
 */
contract Woolball is IWoolball, Ownable, ERC721Enumerable, IWoolballErrors {
    // NONE = uninitiated
    // HUMAN - a human name, e.g., 'neiman#'
    // ARTIFICIAL - a nonhuman name, created by a human, e.g., 'woolball##'
    // SUBNAME - 'car.neiman#'
    enum NameType {
        NONE,
        HUMAN,
        SUBNAME,
        ARTIFICIAL
    }

    // The period users have to verify human names
    uint256 verificationGracePeriod;

    // mapping of approved contract for verifying human
    mapping(address => bool) private _approvedHumanVerifiers;    

    // The main proof of humanity contract
    IhumanVerifier public mainHumanVerifierContract;

    // The Merkle root of the set of trusted entities for makign proof of humanity
    bytes32 public societyRoot;

    struct Name {
        string name;
        NameType nameType;
        uint256 paidTill;
        address creatorWallet; // Creator's wallet address (i.e., which wallet address created the name?)
        uint256 creatorNameID; // Creator's Name ID (only for subnames)
        address data;          // Contract holding the name's data
        uint256[] subnames;    // Array of subnames
        uint256 verifiedTill;  // The last timestamp for which the name was verified
        bytes32 pubkeyX;       // X coordinate of the public key of the name holder
        bytes32 pubkeyY;       // Y coordinate of the public key of the name holder
    }

    // A table of nameID -> Name structure
    mapping(uint256 => Name) private _names;

    mapping(address => uint256) public humanNames;

    INamePricing public namePricingContract;

    modifier requireNameOwner(uint256 nameID) {
        require(
            ownerOf(nameID) == msg.sender,
            "Woolball: sender is not the owner of the name."
        );
        _;
    }

    modifier requireNameExists(uint256 nameID) {
        // Names are registered if their expiration date is bigger than current time
        require(
            doesNameExist(nameID),
            WoolballNonExistentName(nameID)
        );

        _;
    }

    // More forbidden characters will, probably, be added in the future
    modifier requireValidName(string calldata name) {
        // '.' is for subnames
        require(
            !StringUtils.isCharInString(name, "."),
            "Woolball: name can't have '.' characters within in"
        );

        // ',' looks too similar to '.' so it's safer to forbid it
        require(
            !StringUtils.isCharInString(name, ","),
            "Woolball: name can't have '.' characters within in"
        );

        // '#' is for names
        require(
            !StringUtils.isCharInString(name, "#"),
            "Woolball: name can't have '#' characters within in"
        );

        // ':' better safe than sorry
        require(
            !StringUtils.isCharInString(name, ":"),
            "Woolball: name can't have ':' characters within in"
        );

        // '@' better safe than sorry
        require(
            !StringUtils.isCharInString(name, ":"),
            "Woolball: name can't have ':' characters within in"
        );

        // '&' better safe than sorry
        require(
            !StringUtils.isCharInString(name, ":"),
            "Woolball: name can't have ':' characters within in"
        );
        _;
    }

    modifier requireHumanName(uint256 nameID) {
        require(
            _names[nameID].nameType == NameType.HUMAN,
            "Woolball: nameID is not of type Human"
        );
        _;
    }


    /**
     * @dev Constructs a new Woolball registry.
     */
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner,
        address verifierContract,
        address namePricingContractAddress
    ) Ownable(initialOwner) ERC721(name, symbol) {
        mainHumanVerifierContract = IhumanVerifier(verifierContract);
        namePricingContract = INamePricing(namePricingContractAddress);
        verificationGracePeriod = 30;
    }

    /**
     * @notice Creates a new human name with the suffix "#", e.g., "neiman#".
     * @dev The function enforces the following:
     *      - The provided name must be valid (without '#', '.' or similar characters).
     *      - The name must not already be registered.
     *      - The creator must not already own a human name.
     *      - Sufficient payment must be provided to cover the cost of the name.
     * @param name The base name to register (excluding the "#" suffix).
     * @param creator The address of the creator registering the name.
     * @param pubkeyX The public key (X-coordinate) associated with the name.
     * @param pubkeyY The public key (Y-coordinate) associated with the name.
     * @param duration_in_weeks The duration in weeks for which the name is valid.
     * @return nameID The unique ID of the newly created name.
     */
    function newHumanName(
        string calldata name,
        address creator,
        bytes32 pubkeyX,
        bytes32 pubkeyY,
        uint32 duration_in_weeks
    ) public payable virtual requireValidName(name) onlyOwner returns (uint256) {
        // Generate a unique ID for the name by appending "#" and hashing it
        uint256 nameID = uint256(sha256(abi.encodePacked(name, "#")));

        // Verify the name is not already registered
        require(
            !doesNameExist(nameID),
            "Woolball: name is already registered"
        );

        // Verify the creator does not already own a human name
        require(
            !hasHumanName(creator),
            "Woolball: the address already has a name, only one name per address is allwed"
        );

        // Verify that the provided payment covers the name cost
        uint256 price = namePricingContract.cost(name, duration_in_weeks);
        require(msg.value >= price, "Woolball: insufficient funds.");

        _mint(creator, nameID);

        // Set the details of the new name
        _names[nameID].name = name;
        _names[nameID].nameType = NameType.HUMAN;
        _names[nameID].paidTill = block.timestamp + duration_in_weeks * 1 weeks;
        _names[nameID].creatorWallet = creator;
        _names[nameID].verifiedTill = block.timestamp; // need still to verify humanity
        _names[nameID].pubkeyX = pubkeyX;
        _names[nameID].pubkeyY = pubkeyY;

        // Clear all subnames associated with this name if it was previously registered.
        if (_names[nameID].subnames.length > 0)
            _removeAllSubnames(nameID);

        // If the creator previously owned a (now expired) human name, clear its data
        if (humanNames[creator] > 0) {
            clearExpiredName(humanNames[creator]);
        } 

        // Mark the creator's address as associated with the new human name
        humanNames[creator] = nameID;

        // Emit an event indicating that a human name was created
        emit humanNameCreated(name, creator);

        return nameID;
    }

    /**
     * @notice Creates a new artificial name with the suffix "##", e.g., "woolball##".
     * @dev The function enforces the following:
     *      - The provided name must be valid (without '#', '.' or similar characters).
     *      - The creator name ID must correspond to a verified human name.
     *      - The caller must own the creator name ID.
     *      - The name must not already be registered.
     *      - Sufficient payment must be provided to cover the cost of the name.
     * @param name The base name to register (excluding the "##" suffix).
     * @param creatorNameID The ID of the verified human name creating this artificial name.
     * @param pubkeyX The public key (X-coordinate) associated with the name.
     * @param pubkeyY The public key (Y-coordinate) associated with the name.
     * @param duration_in_weeks The duration in weeks for which the name is valid.
     * @return nameID The unique ID of the newly created artificial name.
     */
    function newArtificialName(
        string calldata name,
        uint256 creatorNameID,
        bytes32 pubkeyX,
        bytes32 pubkeyY,
        uint32 duration_in_weeks
    )
        public
        payable
        virtual
        requireValidName(name)
        requireHumanName(creatorNameID)
        requireNameOwner(creatorNameID)
        returns (uint256)
    {
        // Ensure the creator name is verified as a human name
        require(
            isHumanNameVerified(creatorNameID),
            "Woolball: creatorNameID is not verified as a human name"
        );

        // Generate a unique ID for the artificial name by appending "##" and hashing it
        uint256 nameID = uint256(sha256(abi.encodePacked(name, "##")));

        // Verify the name is not already registered
        require(
            !doesNameExist(nameID),
            "Woolball: name is already registered"
        );

        // Verify that the provided payment covers the name cost
        uint256 price = namePricingContract.cost(name, duration_in_weeks);
        require(msg.value >= price, "Woolball: insufficient funds.");

        _mint(msg.sender, nameID);

        // Set the details of the new name
        _names[nameID].name = name;
        _names[nameID].nameType = NameType.ARTIFICIAL;
        _names[nameID].paidTill = block.timestamp + duration_in_weeks * 1 weeks;
        _names[nameID].creatorNameID = creatorNameID;
        _names[nameID].pubkeyX = pubkeyX;
        _names[nameID].pubkeyY = pubkeyY;

        // Clear all subnames associated with this name if it was previously registered.
        if (_names[nameID].subnames.length > 0)
            _removeAllSubnames(nameID);

        // Emit an event indicating that an artificial name was created
        emit humanNameCreated(name, creatorNameID);

        return nameID;
    }

    /**
 * @notice Creates a new subname associated with an existing name. 
 *         For example, given a name "neiman#", a subname "car.neiman#" can be created.
 * @dev The function enforces the following:
 *      - The provided name must be valid (without '#', '.' or similar characters).
 *      - The parent name (nameID) must exist.
 *      - The caller must own the parent name.
 *      - If the parent name is of type HUMAN, it must be verified.
 * @param nameID The ID of the parent name to which the subname will be linked.
 * @param subname The subname to be created (excluding the parent name's suffix).
 * @return subnameID The unique ID of the newly created subname.
 */
    function newSubname(
        uint256 nameID,
        string calldata subname
    )
        public
        virtual
        requireValidName(subname)
        requireNameExists(nameID)
        requireNameOwner(nameID)
        returns (uint256)
    {
        // If the parent name is a HUMAN type, ensure it is verified
        require((_names[nameID].nameType != NameType.HUMAN) || 
                isHumanNameVerified(nameID) , 
            "Woolball: creatorNameID is not verified as a human name");

        // Generate a unique ID for the subname
        uint256 subnameID = uint256(
            sha256(abi.encodePacked(subname, ".", Strings.toString(nameID)))
        );

        // Verify that the subname does not already exist
        require(
            !doesNameExist(subnameID),
            "Woolball: subname already exists"
        );

        _mint(ownerOf(nameID), subnameID);

        // Set the details of the new subname
        _names[subnameID].name = subname;
        _names[subnameID].nameType = NameType.SUBNAME;
        _names[subnameID].paidTill = _names[nameID]
            .paidTill;
        _names[subnameID].creatorNameID = nameID;

        // Update the parent name's list of subnames
        _names[nameID].subnames.push(subnameID);

        // Clear all expired subnames of this subname (for the case it was previously registered)
        if (_names[subnameID].subnames.length > 0)
            _removeAllSubnames(subnameID);

        // Emit an event indicating the creation of a new subname
        emit subnameCreated(subname, nameID, subnameID);

        return subnameID;
    }

    function verifyHuman (
        bytes calldata proof,
        uint256 nameID,
        uint256 verifiedForTimestamp,
        address humanVerifierAddress
    ) public virtual requireNameExists(nameID) {
        bool verificationResult = false;
        IhumanVerifier humanVerifierContract = IhumanVerifier(address(0));

        if (humanVerifierAddress == address(0)) {
            // User default verifier if none is given
            humanVerifierContract = mainHumanVerifierContract;
        } else {
            // Check the given verifier is authorized
            require (_approvedHumanVerifiers[humanVerifierAddress], "Woolball: humanVerifierAddress is not an approved verifying contract.");
            
            // Cast the verifier address to IhumanVerifier interface
            humanVerifierContract = IhumanVerifier(humanVerifierAddress);
        }

        verificationResult = humanVerifierContract.verify(
            proof,
            _names[nameID].pubkeyX,
            _names[nameID].pubkeyY,
            nameID,
            ownerOf(nameID),
            societyRoot,
            verifiedForTimestamp
        );

        require(verificationResult, "Woolball: verification failed");

        // Update name verified timestamp
        _names[nameID].verifiedTill = verifiedForTimestamp;

        emit humanVerified(nameID);
    }

    // Removes an existing subname
    function removeSubname(
        uint256 subnameID
    ) public virtual requireNameOwner(subnameID) {
        require(
            _names[subnameID].paidTill > 0,
            "Woolball: Subname is already removed"
        );

        _removeSubname(subnameID);
    }

    function clearExpiredName(uint256 nameID) public virtual {
        require(
            getExpirationTimestamp(nameID) < block.timestamp,
            "Woolball: the name is not expired."
        );

        // Delete all the subnames of the name
        if (_names[nameID].subnames.length > 0)
            _removeAllSubnames(nameID);

        // Delete name
        delete _names[nameID];
        _burn(nameID);
    }

    /**
     * @dev Sets the data contract address for the specified name.
     * @param nameID The name to update.
     * @param dataContract The address of the data contract.
     */
    function setDataContract(
        uint256 nameID,
        address dataContract
    ) public virtual requireNameOwner(nameID) {
        _names[nameID].data = dataContract;
    }

    /**
     * @dev Sets the name pricing contract address for Woolball.
     * @param _namePricingContract The address of the name pricing contract.
     */
    function setNamePricingContract(
        address _namePricingContract
    ) public virtual onlyOwner {
        namePricingContract = INamePricing(_namePricingContract);
    }

    function setSocietyRoot (bytes32 _societyRoot) public virtual onlyOwner {
        societyRoot = _societyRoot;
    }

    function setPubkey(
        uint256 nameID,
        bytes32 pubkeyX,
        bytes32 pubkeyY
    ) public virtual requireNameOwner(nameID) {
        _names[nameID].pubkeyX = pubkeyX;
        _names[nameID].pubkeyY = pubkeyY;
    }

    function addHumanVerifierContract (
        address humanVerifierContract
    ) public onlyOwner {
        _approvedHumanVerifiers[humanVerifierContract] = true;
    }

    function removeHumanVerifierContract (
        address humanVerifierContract
    ) public onlyOwner {
        _approvedHumanVerifiers[humanVerifierContract] = false;
    }

    /**
    * @notice Retrieves the expiration timestamp of a name based on its type.
     * @dev Handles the following scenarios:
     *      - For `HUMAN` names, returns the earlier of `paidTill` or `verifiedTill + grace period`.
     *      - For `ARTIFICIAL` names, directly returns `paidTill`.
     *      - For `SUBNAME` names, retrieves the expiration timestamp of the creator name recursively.
     *      - Returns `0` for unknown or invalid name types.
     * @param nameID The ID of the name to check.
     * @return expirationTimestamp The expiration timestamp of the name, or `0` if invalid or expired.
     */
    function getExpirationTimestamp(
        uint256 nameID
    ) public view virtual returns (uint256) {
        // For HUMAN names, return the minimum of paidTill and verifiedTill + grace period
        if ((_names[nameID].nameType == NameType.HUMAN) ) {
             uint256 paidTill = _names[nameID].paidTill;
             uint256 verifiedTillPlusGrace = _names[nameID].verifiedTill + verificationGracePeriod * 1 days;
             uint256 expirationTimestamp = paidTill < verifiedTillPlusGrace ? paidTill : verifiedTillPlusGrace;

             return expirationTimestamp > block.timestamp ? expirationTimestamp : 0;

        }
        // For ARTIFICIAL names, directly return paidTill
        else if (_names[nameID].nameType == NameType.ARTIFICIAL) {
            uint256 expirationTimestamp = _names[nameID].paidTill;

            return expirationTimestamp > block.timestamp ? expirationTimestamp : 0;
        }
        // For SUBNAME names, retrieve the expiration timestamp of the creator name recursively
        else if (_names[nameID].nameType == NameType.SUBNAME) {
            uint256 creatorNameID = _names[nameID].creatorNameID;
            return getExpirationTimestamp(creatorNameID);
        } 
        // For unknown or invalid name types, return 0
        else { 
            return 0;
        }
    }

    /**
     * @notice Checks if the given address owns a valid human name.
     * @param potentialOwner The address to check for ownership of a human name.
     * @return True if the address owns a valid human name, false otherwise.
     */
    function hasHumanName(address potentialOwner) public view returns (bool) {
        // Check if the address has a registered human name
        uint256 nameID = humanNames[potentialOwner];
        return nameID != 0 && getExpirationTimestamp(nameID) > 0;
    }

    /**
     * @notice Checks if a human name is verified. 
     * @notice A human name is verified if it has not expired (`paidTill > block.timestamp`) 
     * @notice and is within the verification period (`verifiedTill > block.timestamp`).
     * @param nameID The ID of the human name to check.
     * @return True if the human name is verified, false otherwise.
     */
    function isHumanNameVerified(uint256 nameID) public view requireHumanName(nameID) returns (bool) {
        return _names[nameID].paidTill >= block.timestamp && _names[nameID].verifiedTill >= block.timestamp;    
    }

    /**
     * @notice Checks whether a name exists.
     * @dev A name is considered to exist if its expiration timestamp is greater than zero.
     * @param nameID The ID of the name to check.
     * @return True if the name exists, false otherwise.
     */
    function doesNameExist(uint256 nameID) public view returns (bool) {
        return getExpirationTimestamp(nameID) > 0;
    }

    /**
     * @dev Returns the address of the data contract for the specified name.
     * @param nameID The specified name.
     * @return address of the data contract.
     */
    function data(
        uint256 nameID
    ) public view virtual requireNameExists(nameID) returns (address) {
        return _names[nameID].data;
    }

    // Returns the amount of registered subnames.
    // Remark: the number might also include expired subnames.
    function subnamesAmount(
        uint256 nameID
    ) public view virtual returns (uint256) {
        return _names[nameID].subnames.length;
    }

    function subnameIndex(
        uint256 nameID,
        uint256 index
    ) public view virtual returns (uint256) {
        return _names[nameID].subnames[index];
    }

    function getParentID(
        uint256 nameID
    ) public view virtual  returns (uint256) {
        return _names[nameID].creatorNameID;
    }

    // uint8 representes ENUM
    function getNameType(uint256 nameID) public view virtual returns (uint8) {
        return uint8(_names[nameID].nameType);
    }

    function getName(
        uint256 nameID
    ) public view requireNameExists(nameID) returns (string memory) {
        string memory name;

        if (_names[nameID].nameType == NameType.HUMAN)
            name = _names[nameID].name;
        else {
            // name is a Subname
            name = _names[nameID].name;
            uint256 creatorSubnameID = _names[nameID].creatorNameID;

            do {
                name = string.concat(name, ".", _names[creatorSubnameID].name);

                // update creatorSubnameID to the parent of the current part of the name
                creatorSubnameID = _names[creatorSubnameID].creatorNameID;
            } while (creatorSubnameID > 0);
        }

        return name;
    }

    // Removes an existing subname
    function _removeSubname(uint256 subnameID) internal {
        uint256 creatorID = _names[subnameID].creatorNameID;
        uint256[] storage subnames = _names[creatorID].subnames;

        uint256 i = 0;
        while (i < subnames.length) {
            if (subnames[i] == subnameID) {
                // Swap with the last element and then pop
                subnames[i] = subnames[subnames.length - 1];
                subnames.pop();
                break; // Exit as the subname has been found and removed
            }
            i++;
        }

        // Remove all existing subnames of the subname
        _removeAllSubnames(subnameID);

        // Delete the subname
        delete _names[subnameID];
        _burn(subnameID);
    }

    // Remove all subnames of a name
    function _removeAllSubnames(uint256 nameID) internal {
        for (uint256 i = 0; i < _names[nameID].subnames.length; i++) {
            uint256 subnameID = _names[nameID].subnames[i];
            _removeAllSubnames(subnameID);
            delete _names[subnameID];
            _burn(subnameID);
        }
    }

    function ownerOf(uint256 nameID) public view virtual override(ERC721, IERC721) requireNameExists(nameID) returns (address) {
        return ERC721.ownerOf(nameID);
    }

    // Handles the specifics of transfering names.
    function transferFrom(address from, address to, uint256 tokenID) public virtual override(ERC721, IERC721) requireNameExists(tokenID) {
        // Verify conditions for transfering a human name
        if (_names[tokenID].nameType == NameType.HUMAN) {
            // An address can at most own one human name
            require(
                hasHumanName(to),
                "Woolball: target already has a name."
            );

            // Transfering a human name nullifies its verification
            if (_names[tokenID].verifiedTill > block.timestamp) {
                _names[tokenID].verifiedTill = block.timestamp;
            }
        }

        ERC721.transferFrom(from, to, tokenID);
    }
}