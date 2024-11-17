pragma solidity >=0.8.28;

import "./interfaces/IhumanVerifier.sol";
import "./plonk_vk.sol";

contract humanVerfierCertificate is IHumanVerifier {
    UltraVerifier humanVerifierContract;

    function verify (
        bytes calldata proof,
        uint256 nameID,
        uint256 verifiedForTimestamp
    ) public returns (bool) {

        bytes32[] memory publicInputs = new bytes32[](6);

        // Prepare the public data
        publicInputs[0] = _names[nameID].pubkeyX;
        publicInputs[1] = _names[nameID].pubkeyY;
        publicInputs[2] = trustKernelHash;
        publicInputs[3] = bytes32(verifiedForTimestamp);
        publicInputs[4] = bytes32(uint256(uint160(ownerOf(nameID))) << 96);
        publicInputs[5] = bytes32(nameID);

        return humanVerifierContract.verify(
            proof,
            publicInputs
        );
    }
}
