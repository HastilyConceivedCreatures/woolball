// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Woolball.sol";
import "../src/HumanVerifierCertificate.sol";
import "../src/plonk_vk.sol";
import "../src/NamePricing.sol";
import "../src/interfaces/INamePricing.sol";
import "../src/StringUtils.sol";
import "../src/interfaces/IHumanVerifier.sol";
import "../src/plonk_vk.sol";

contract WoolballScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_ANVIL");

        // Retrieve the deployer's address from the private key
        address deployerAddress = vm.addr(deployerPrivateKey);

        // Start broadcasting transactions from the deployer account
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contracts
        UltraVerifier humanVerifierContract = new UltraVerifier();
        IHumanVerifier humanVerifier = IHumanVerifier(
            new HumanVerfierCertificate(humanVerifierContract)
        );
        INamePricing namePricing = INamePricing(new NamePricing());

        // Pass the deployer address instead of msg.sender
        new Woolball("Woolball", "WLBL", deployerAddress, humanVerifier, namePricing);

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
