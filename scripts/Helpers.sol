// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GhoToken} from 'gho-core/gho/GhoToken.sol';
import {IGhoToken} from 'gho-core/gho/interfaces/IGhoToken.sol';
import {GhoOracle} from 'gho-core/facilitators/aave/oracle/GhoOracle.sol';
import {GhoAToken} from 'gho-core/facilitators/aave/tokens/GhoAToken.sol';
import {GhoVariableDebtToken} from 'gho-core/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {GhoStableDebtToken} from 'gho-core/facilitators/aave/tokens/GhoStableDebtToken.sol';
import {GhoInterestRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {GhoDiscountRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {UiGhoDataProvider} from 'gho-core/facilitators/aave/misc/UiGhoDataProvider.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IAaveIncentivesController} from '@aave/core-v3/contracts/interfaces/IAaveIncentivesController.sol';
import {GhoFlashMinter} from 'gho-core/facilitators/flashMinter/GhoFlashMinter.sol';
import {GhoListingPayload} from '../src/contracts/GhoListingPayload.sol';

library Helpers {
  function deployGhoToken(address owner) internal returns (address) {
    GhoToken gho = new GhoToken(owner);
    return address(gho);
  }

  struct AaveFacilitatorData {
    address ghoOracle;
    address ghoAToken;
    address ghoVariableDebtToken;
    address ghoStableDebtToken;
    address ghoInterestRateStrategy;
    address ghoDiscountRateStrategy;
  }

  function deployAaveFacilitator(
    address pool,
    uint256 ghoInterestRate
  ) internal returns (AaveFacilitatorData memory) {
    GhoOracle ghoOracle = new GhoOracle();
    GhoAToken ghoAToken = new GhoAToken(IPool(pool));
    ghoAToken.initialize(
      IPool(pool),
      address(0),
      address(0),
      IAaveIncentivesController(address(0)),
      0,
      'GHO_ATOKEN_IMPL',
      'GHO_ATOKEN_IMPL',
      '0x0'
    );
    GhoStableDebtToken ghoStableDebtToken = new GhoStableDebtToken(IPool(pool));
    ghoStableDebtToken.initialize(
      IPool(pool),
      address(0),
      IAaveIncentivesController(address(0)),
      0,
      'GHO_STABLE_DEBT_TOKEN_IMPL',
      'GHO_STABLE_DEBT_TOKEN_IMPL',
      '0x0'
    );
    GhoVariableDebtToken ghoVariableDebtToken = new GhoVariableDebtToken(IPool(pool));
    ghoVariableDebtToken.initialize(
      IPool(pool),
      address(0),
      IAaveIncentivesController(address(0)),
      0,
      'GHO_VARIABLE_DEBT_TOKEN_IMPL',
      'GHO_VARIABLE_DEBT_TOKEN_IMPL',
      '0x0'
    );
    GhoInterestRateStrategy ghoInterestRateStrategy = new GhoInterestRateStrategy(ghoInterestRate);
    GhoDiscountRateStrategy ghoDiscountRateStrategy = new GhoDiscountRateStrategy();

    return
      AaveFacilitatorData({
        ghoOracle: address(ghoOracle),
        ghoAToken: address(ghoAToken),
        ghoVariableDebtToken: address(ghoVariableDebtToken),
        ghoStableDebtToken: address(ghoStableDebtToken),
        ghoInterestRateStrategy: address(ghoInterestRateStrategy),
        ghoDiscountRateStrategy: address(ghoDiscountRateStrategy)
      });
  }

  function deployFlashMinterFacilitator(
    address ghoToken,
    address collector,
    uint256 flashmintFee,
    address addressesProvider
  ) internal returns (address) {
    GhoFlashMinter flashMinter = new GhoFlashMinter(
      ghoToken,
      collector,
      flashmintFee,
      addressesProvider
    );
    return address(flashMinter);
  }

  function deployGhoUiDataProvider(address pool, address ghoToken) internal returns (address) {
    UiGhoDataProvider ghoUiGhoDataProvider = new UiGhoDataProvider(
      IPool(pool),
      IGhoToken(ghoToken)
    );
    return address(ghoUiGhoDataProvider);
  }

  function deployListingPayload(
    address ghoOracle,
    address ghoAToken,
    address ghoVariableDebtToken,
    address ghoStableDebtToken,
    address ghoInterestRateStrategy,
    address ghoDiscountRateStrategy
  ) internal returns (address) {
    GhoListingPayload payload = new GhoListingPayload(
      ghoOracle,
      ghoAToken,
      ghoVariableDebtToken,
      ghoStableDebtToken,
      ghoInterestRateStrategy,
      ghoDiscountRateStrategy
    );
    return address(payload);
  }
}
