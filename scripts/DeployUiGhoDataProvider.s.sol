// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {Script} from 'forge-std/Script.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GhoListingPayload} from '../src/contracts/GhoListingPayload.sol';
import {Helpers} from './Helpers.sol';
import './Constants.sol';

contract DeployUiGhoDataProvider is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');

    vm.startBroadcast(deployerPrivateKey);

    address ghoUiDataProvider = Helpers.deployGhoUiDataProvider(
      address(AaveV3Ethereum.POOL),
      GhoListingPayload(PAYLOAD).GHO_TOKEN()
    );
    console2.log('POOL:', address(AaveV3Ethereum.POOL));
    console2.log('GHO_TOKEN:', GhoListingPayload(PAYLOAD).GHO_TOKEN());

    vm.stopBroadcast();
  }
}
