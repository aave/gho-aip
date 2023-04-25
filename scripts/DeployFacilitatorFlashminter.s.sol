// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GhoFlashMinter} from 'gho-core/facilitators/flashMinter/GhoFlashMinter.sol';

contract DeployFacilitatorFlashminter is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    address GHO_TOKEN = address(0);
    uint256 FLASHMINT_FEE = 100;

    GhoFlashMinter flashMinter = new GhoFlashMinter(
      GHO_TOKEN,
      address(AaveV3Ethereum.COLLECTOR),
      FLASHMINT_FEE,
      address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)
    );
    vm.stopBroadcast();
  }
}
