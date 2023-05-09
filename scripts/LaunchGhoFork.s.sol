// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {Script} from 'forge-std/Script.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {Helpers} from './Helpers.sol';
import './Constants.sol';

contract LaunchGhoFork is Script {
  function run() external {
    // Deploy GhoToken
    uint256 ghoDeployerPrivateKey = vm.envUint('PRIVATE_KEY_GHO_TOKEN');
    address ghoDeployerAddress = vm.addr(ghoDeployerPrivateKey);
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address deployerAddress = vm.addr(deployerPrivateKey);
    console2.log('PRIVATE_KEY_GHO_TOKEN', ghoDeployerPrivateKey);
    console2.log('PRIVATE_KEY', deployerPrivateKey);
    console2.log('GhoDeployerAddress', ghoDeployerAddress);
    console2.log('GhoDeployerBalance', address(ghoDeployerAddress).balance);
    console2.log('DeployerAddress', deployerAddress);
    console2.log('deployerBalance', address(deployerAddress).balance);
    console2.log('BlockNumber', block.number);

    vm.startBroadcast(ghoDeployerPrivateKey);
    address ghoToken = Helpers.deployGhoToken(GHO_TOKEN_OWNER);
    console2.log('GhoToken:', ghoToken);
    // Transfer funds to the other deployer
    payable(deployerAddress).transfer(1 ether);
    vm.stopBroadcast();

    vm.startBroadcast(deployerPrivateKey);

    // Deploy AaveFacilitator
    Helpers.AaveFacilitatorData memory aaveData = Helpers.deployAaveFacilitator(
      address(AaveV3Ethereum.POOL),
      ghoToken,
      VARIABLE_BORROW_RATE
    );
    console2.log('GhoOracle:', aaveData.ghoOracle);
    console2.log('GhoATokenImpl:', aaveData.ghoAToken);
    console2.log('GhoVariableDebtTokenImpl:', aaveData.ghoVariableDebtToken);
    console2.log('GhoStableDebtTokenImpl:', aaveData.ghoStableDebtToken);
    console2.log('GhoInterestRateStrategy:', aaveData.ghoInterestRateStrategy);
    console2.log('GhoDiscountRateStrategy:', aaveData.ghoDiscountRateStrategy);
    console2.log('GhoUiGhoDataProvider:', aaveData.ghoUiGhoDataProvider);

    // Deploy FlashMinting Facilitator
    address flashminter = Helpers.deployFlashMinterFacilitator(
      ghoToken,
      address(AaveV3Ethereum.COLLECTOR),
      FLASHMINT_FEE,
      address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)
    );
    console2.log('FlashMinter:', flashminter);

    // Deploy GHO Payload
    address payload = Helpers.deployListingPayload(
      ghoToken,
      flashminter,
      aaveData.ghoOracle,
      aaveData.ghoAToken,
      aaveData.ghoVariableDebtToken,
      aaveData.ghoStableDebtToken,
      aaveData.ghoInterestRateStrategy,
      aaveData.ghoDiscountRateStrategy
    );
    console2.log('Payload:', payload);

    vm.stopBroadcast();
  }
}
