pragma solidity >=0.8.28;

interface IWoolballErrors {
    /**
     * @dev Indicates a `nameID` whose for which `getExpirationTimestamp` is zero.
     * @dev Expiration timestamp zero of a name implies it either never existed or it expired already.
     * @param nameID Identifier number of a name.
     */
    error WoolballNonExistentName(uint256 nameID);
}