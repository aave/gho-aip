// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {GhoListingPayload} from '../src/contracts/GhoListingPayload.sol';

contract DeployGhoListingPayload is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    new GhoListingPayload(
      address(0), // ghoToken
      address(0), // ghoFlashMinter
      address(0),// ghoOracle
      address(0),// ghoAToken
      address(0),// ghoVariableDebtToken
      address(0),// ghoStableDebtToken
      address(0),// ghoInterestRateStrategy
      address(0)// ghoDiscountRateStrategy
    );

    vm.stopBroadcast();
  }
}
