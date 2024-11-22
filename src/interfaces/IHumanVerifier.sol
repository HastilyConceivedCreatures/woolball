pragma solidity >=0.8.28;


interface IHumanVerifier {
    function verify (
        bytes calldata proof,
        bytes32 pubkeyX,
        bytes32 pubkeyY,
        uint256 nameID,
        address nameOwner,
        bytes32 societyRoot,
        uint256 verifiedForTimestamp
    ) view external returns (bool);
}
