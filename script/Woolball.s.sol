// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Woolball.sol";
import "../src/HumanVerifierCertificate.sol";
import "../src/plonk_vk.sol";
import "../src/NamePricing.sol";
import "../src/StringUtils.sol";

contract WoolballScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_BASE_SEPOLIA");
        vm.startBroadcast(deployerPrivateKey);

        ICutrixData cutrixData;

        cutrixData = ICutrixData(new CutrixData()); 

        new Cutrix(cutrixData);

        vm.stopBroadcast();
    }
}

