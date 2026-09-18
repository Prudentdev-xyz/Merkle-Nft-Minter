// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MerkleMinter} from "../src/MerkleMinter.sol";

contract DeployMerkleMinter is Script {
    function run() external returns (MerkleMinter) {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        string memory name_ = "MerkleMinter";
        string memory symbol_ = "MMNFT";
        uint256 price_ = 0.01 ether;
        uint256 maxSupply_ = 1000;
        uint256 publicMaxPerWallet_ = 5;
        bytes32 merkleRoot_ = bytes32(0); // placeholder — update with real allowlist root later
        string memory baseURI_ = "ipfs://REPLACE_WITH_YOUR_CID/";

        vm.startBroadcast(deployerKey);

        MerkleMinter minter = new MerkleMinter(
            name_,
            symbol_,
            price_,
            maxSupply_,
            publicMaxPerWallet_,
            merkleRoot_,
            baseURI_
        );

        vm.stopBroadcast();

        console.log("MerkleMinter deployed at:", address(minter));

        return minter;
    }
}