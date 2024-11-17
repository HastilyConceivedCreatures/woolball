pragma solidity >=0.8.28;


interface IHumanVerifier {
    function verify (
        bytes calldata proof,
        uint256 nameID,
        uint256 verifiedForTimestamp
    ) external returns (bool);
}
