// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Woolball.sol";
import "../src/HumanVerifierCertificate.sol";
import "../src/ZKVerifier.sol";
import "../src/NamePricing.sol";
import "../src/interfaces/INamePricing.sol";
import "../src/StringUtils.sol";
import "../src/interfaces/IHumanVerifier.sol";

contract WoolballScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_OP_SEPOLIA");

        // Retrieve the deployer's address from the private key
        address deployerAddress = vm.addr(deployerPrivateKey);

        // Start broadcasting transactions from the deployer account
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contracts
        UltraVerifier humanVerifierContract = new UltraVerifier();
        console.log("UltraVerifier Contract Address:", address(humanVerifierContract));

        IHumanVerifier humanVerifier = IHumanVerifier(
            new HumanVerfierCertificate(humanVerifierContract)
        );
        console.log("humanVerifier Contract Address:", address(humanVerifier));

        INamePricing namePricing = INamePricing(new NamePricing());
        console.log("namePricing Contract Address:", address(namePricing));

        // Pass the deployer address instead of msg.sender
        Woolball woolballContract = new Woolball("Woolball", "WLBL", deployerAddress, humanVerifier, namePricing);
        console.log("Woolball Contract Address:", address(woolballContract));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
