// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console } from "forge-std/Script.sol";
import { EscrowMarketplace } from "../src/EscrowMarketplace.sol";

contract DeployEscrowMarketplace is Script {
    function run() public {
        // If provide private key here, will not need to provide when run script command
        uint256 deployerPrivateKey =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));

        vm.startBroadcast(deployerPrivateKey);
        EscrowMarketplace escrowMarketplace = new EscrowMarketplace();
        console.log("EscrowMarketplace deployed to:", address(escrowMarketplace));
        vm.stopBroadcast();
    }
}
