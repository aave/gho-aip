// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {Script} from 'forge-std/Script.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {GhoListingPayload} from '../src/contracts/GhoListingPayload.sol';
import {Helpers} from './Helpers.sol';
import './Constants.sol';

contract LaunchGho is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address deployerAddress = vm.addr(deployerPrivateKey);
    console2.log('PRIVATE_KEY', deployerPrivateKey);
    console2.log('DeployerAddress', deployerAddress);
    console2.log('deployerBalance', address(deployerAddress).balance);
    console2.log('BlockNumber', block.number);

    vm.startBroadcast(deployerPrivateKey);

    // Deploy AaveFacilitator
    Helpers.AaveFacilitatorData memory aaveData = Helpers.deployAaveFacilitator(
      address(AaveV3Ethereum.POOL),
      VARIABLE_BORROW_RATE
    );
    console2.log('GhoOracle:', aaveData.ghoOracle);
    console2.log('GhoATokenImpl:', aaveData.ghoAToken);
    console2.log('GhoVariableDebtTokenImpl:', aaveData.ghoVariableDebtToken);
    console2.log('GhoStableDebtTokenImpl:', aaveData.ghoStableDebtToken);
    console2.log('GhoInterestRateStrategy:', aaveData.ghoInterestRateStrategy);
    console2.log('GhoDiscountRateStrategy:', aaveData.ghoDiscountRateStrategy);

    // Deploy GHO Payload
    address payload = Helpers.deployListingPayload(
      aaveData.ghoOracle,
      aaveData.ghoAToken,
      aaveData.ghoVariableDebtToken,
      aaveData.ghoStableDebtToken,
      aaveData.ghoInterestRateStrategy,
      aaveData.ghoDiscountRateStrategy
    );
    console2.log('GhoToken:', GhoListingPayload(payload).GHO_TOKEN());
    console2.log('FlashMinter:', GhoListingPayload(payload).GHO_FLASHMINTER());
    console2.log('Payload:', payload);

    // Deploy GhoUiDataProvider
    address ghoUiDataProvider = Helpers.deployGhoUiDataProvider(
      address(AaveV3Ethereum.POOL),
      GhoListingPayload(payload).GHO_TOKEN()
    );
    console2.log('GhoUiDataProvider:', ghoUiDataProvider);

    vm.stopBroadcast();
  }
}
