// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {GhoToken} from 'gho-core/gho/GhoToken.sol';

contract DeployGhoToken is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    GhoToken ghoToken = new GhoToken();
    // TODO Move ownership to proper Executor / Governance control

    vm.stopBroadcast();
  }
}
