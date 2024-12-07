pragma solidity >=0.8.28;

import "./interfaces/IHumanVerifier.sol";
import "./ZKVerifier.sol";

contract HumanVerfierCertificate is IHumanVerifier {
    UltraVerifier internal humanVerifierContract;

    constructor(UltraVerifier humanVerifierContractConstructor) {
        humanVerifierContract = humanVerifierContractConstructor;
    }

    function verify (
        bytes calldata proof,
        bytes32 pubkeyX,
        bytes32 pubkeyY,
        uint256 nameID,
        address nameOwner,
        bytes32 societyRoot,
        uint256 verifiedForTimestamp
    ) view public returns (bool) {
        bytes32[] memory publicInputs = new bytes32[](6);

        // Truncate by right shifting two bits in order to fit the sha256 into 254 bits
        uint256 nameID_254bits = nameID >> 2;

        // Prepare the public data
        publicInputs[0] = pubkeyX;
        publicInputs[1] = pubkeyY;
        publicInputs[2] = bytes32(nameID_254bits);
        publicInputs[3] = bytes32(uint256(uint160(nameOwner)));
        publicInputs[4] = societyRoot;
        publicInputs[5] = bytes32(verifiedForTimestamp);

        return humanVerifierContract.verify(
            proof,
            publicInputs
        );
    }
}
