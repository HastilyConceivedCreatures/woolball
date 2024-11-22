pragma solidity >=0.8.28;

import "./interfaces/IHumanVerifier.sol";
import "./plonk_vk.sol";

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

        // Prepare the public data
        publicInputs[0] = pubkeyX;
        publicInputs[1] = pubkeyY;
        publicInputs[4] = bytes32(uint256(uint160(nameOwner)) << 96);
        publicInputs[2] = societyRoot;
        publicInputs[3] = bytes32(verifiedForTimestamp);
        publicInputs[5] = bytes32(nameID);

        return humanVerifierContract.verify(
            proof,
            publicInputs
        );
    }
}
