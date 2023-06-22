// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {Script} from 'forge-std/Script.sol';

import {ZeroDiscountRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/ZeroDiscountRateStrategy.sol';

contract DeployZeroDiscountRateStrategy is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    ZeroDiscountRateStrategy zeroDiscountRateStrategy = new ZeroDiscountRateStrategy();

    vm.stopBroadcast();
    console2.log('ZeroDiscountRateStrategy:', address(zeroDiscountRateStrategy));
  }
}
