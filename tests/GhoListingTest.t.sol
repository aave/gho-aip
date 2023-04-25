// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {ProtocolV3TestBase, ReserveConfig, ReserveTokens} from 'aave-helpers/src/ProtocolV3TestBase.sol';

import {GhoToken} from 'gho-core/gho/GhoToken.sol';
import {IGhoToken} from 'gho-core/gho/interfaces/IGhoToken.sol';
import {GhoOracle} from 'gho-core/facilitators/aave/oracle/GhoOracle.sol';
import {GhoAToken} from 'gho-core/facilitators/aave/tokens/GhoAToken.sol';
import {IGhoAToken} from 'gho-core/facilitators/aave/tokens/interfaces/IGhoAToken.sol';
import {GhoFlashMinter} from 'gho-core/facilitators/flashMinter/GhoFlashMinter.sol';
import {GhoVariableDebtToken} from 'gho-core/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {IGhoVariableDebtToken} from 'gho-core/facilitators/aave/tokens/interfaces/IGhoVariableDebtToken.sol';
import {GhoInterestRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {GhoDiscountRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {AggregatedStakedAaveV3} from 'aave-stk-v1-5/interfaces/AggregatedStakedAaveV3.sol';
import {StableDebtToken} from '@aave/core-v3/contracts/protocol/tokenization/StableDebtToken.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';

import {GhoListingPayload} from '../src/contracts/GhoListingPayload.sol';

// TODO STKAAVE hook is not being tested
contract GhoListingTest is ProtocolV3TestBase {
  using stdStorage for StdStorage;

  address public constant STK_AAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;
  address public constant AAVE_SHORT_EXECUTOR = 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5;

  function testListingComplete() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16981480);

    GhoToken ghoToken = new GhoToken();

    GhoListingPayload payload = new GhoListingPayload(
      address(ghoToken),
      address(
        new GhoFlashMinter(
          address(ghoToken),
          AaveV3Ethereum.COLLECTOR,
          1_00,
          address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)
        )
      ),
      address(new GhoOracle()),
      address(new GhoAToken(IPool(address(AaveV3Ethereum.POOL)))),
      address(new GhoVariableDebtToken(IPool(address(AaveV3Ethereum.POOL)))),
      address(new StableDebtToken(IPool(address(AaveV3Ethereum.POOL)))),
      address(new GhoInterestRateStrategy(2500)),
      address(new GhoDiscountRateStrategy())
    );

    // Simulate GOV action
    ghoToken.transferOwnership(address(payload));
    vm.startPrank(AaveV3Ethereum.ACL_ADMIN);
    AaveV3Ethereum.ACL_MANAGER.addPoolAdmin(address(payload));
    vm.stopPrank();

    _testListing(address(payload));
  }

  function testListingWithPayload() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16981480);
    address GHO_AIP = address(0); // TODO

    // Simulate GOV action
    vm.startPrank(AaveV3Ethereum.ACL_ADMIN);
    AaveV3Ethereum.ACL_MANAGER.addPoolAdmin(GHO_AIP);
    vm.stopPrank();

    _testListing(GHO_AIP);
  }

  function _testListing(address payloadAddress) public {
    GhoListingPayload payload = GhoListingPayload(payloadAddress);

    ReserveConfig[] memory allConfigsBefore = _getReservesConfigs(AaveV3Ethereum.POOL);

    createConfigurationSnapshot('preTestEngineListing', AaveV3Ethereum.POOL);

    payload.execute();

    createConfigurationSnapshot('postTestEngineListing', AaveV3Ethereum.POOL);

    diffReports('preTestEngineListing', 'postTestEngineListing');

    ReserveConfig[] memory allConfigsAfter = _getReservesConfigs(AaveV3Ethereum.POOL);

    ReserveConfig memory expectedAssetConfig = ReserveConfig({
      symbol: 'GHO',
      underlying: payload.GHO_TOKEN(),
      aToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
      variableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
      stableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
      decimals: payload.GHO_DECIMALS(),
      ltv: payload.LTV(),
      liquidationThreshold: payload.LIQUIDATION_THRESHOLD(),
      liquidationBonus: payload.LIQUIDATION_BONUS(),
      liquidationProtocolFee: payload.LIQ_PROTOCOL_FEE(),
      reserveFactor: payload.RESERVE_FACTOR(),
      usageAsCollateralEnabled: false,
      borrowingEnabled: true,
      interestRateStrategy: _findReserveConfigBySymbol(allConfigsAfter, 'GHO').interestRateStrategy,
      stableBorrowRateEnabled: false,
      isActive: true,
      isFrozen: false,
      isSiloed: false,
      isBorrowableInIsolation: false,
      isFlashloanable: false,
      supplyCap: 0,
      borrowCap: 0,
      debtCeiling: payload.DEBT_CEILING(),
      eModeCategory: 0
    });

    _validateReserveConfig(expectedAssetConfig, allConfigsAfter);

    _noReservesConfigsChangesApartNewListings(allConfigsBefore, allConfigsAfter);

    _validateReserveTokensImpls(
      AaveV3Ethereum.POOL_ADDRESSES_PROVIDER,
      _findReserveConfigBySymbol(allConfigsAfter, 'GHO'),
      ReserveTokens({
        aToken: payload.GHO_ATOKEN_IMPL(),
        stableDebtToken: payload.GHO_STABLE_DEBT_TOKEN_IMPL(),
        variableDebtToken: payload.GHO_VARIABLE_DEBT_TOKEN_IMPL()
      })
    );

    _validateAssetSourceOnOracle(
      AaveV3Ethereum.POOL_ADDRESSES_PROVIDER,
      payload.GHO_TOKEN(),
      payload.GHO_ORACLE()
    );

    _validateGhoConfigurationPostProposal(payload);
    _validateGhoActionsPostProposal(allConfigsAfter);
  }

  function _validateGhoConfigurationPostProposal(GhoListingPayload payload) internal {
    // GHO
    assertEq(IGhoToken(payload.GHO_TOKEN()).totalSupply(), 0);
    // assertEq(GhoToken(payload.GHO_TOKEN()).owner(), AAVE_SHORT_EXECUTOR); // TODO

    // Facilitators
    assertEq(IGhoToken(payload.GHO_TOKEN()).getFacilitatorsList().length, 2);

    // Aave Facilitator
    (address ghoATokenAddress, , address ghoVariableDebtTokenAddress) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveTokensAddresses(payload.GHO_TOKEN());

    (uint256 aaveCapacity, uint256 aaveLevel) = IGhoToken(payload.GHO_TOKEN()).getFacilitatorBucket(
      ghoATokenAddress
    );
    assertEq(aaveCapacity, payload.FACILITATOR_AAVE_BUCKET_CAPACITY());
    assertEq(aaveLevel, 0);

    // GhoAToken config
    assertEq(IGhoAToken(ghoATokenAddress).getVariableDebtToken(), ghoVariableDebtTokenAddress);
    assertEq(IGhoAToken(ghoATokenAddress).getGhoTreasury(), AaveV3Ethereum.COLLECTOR);

    // GhoVariableDebtToken config
    assertEq(IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getAToken(), ghoATokenAddress);
    assertEq(
      IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getDiscountRateStrategy(),
      payload.GHO_DISCOUNT_RATE_STRATEGY()
    );
    assertEq(IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getDiscountToken(), STK_AAVE);

    // GhoOracle
    assertEq(AaveV3Ethereum.ORACLE.getSourceOfAsset(payload.GHO_TOKEN()), payload.GHO_ORACLE());
    assertEq(AaveV3Ethereum.ORACLE.getAssetPrice(payload.GHO_TOKEN()), 1e8);

    // FlashMinter
    (uint256 flashMinterCapacity, uint256 flashMinterLevel) = IGhoToken(payload.GHO_TOKEN())
      .getFacilitatorBucket(payload.GHO_FLASHMINTER());
    assertEq(flashMinterCapacity, payload.FACILITATOR_FLASHMINTER_BUCKET_CAPACITY());
    assertEq(flashMinterLevel, 0);

    // StkAAVE
    // assertEq(AggregatedStakedAaveV3(STK_AAVE).ghoDebtToken(), ghoVariableDebtTokenAddress); // TODO
  }

  function _validateGhoActionsPostProposal(ReserveConfig[] memory allReservesConfigs) internal {
    address ALICE = address(0x111);

    // Supply some collateral
    uint256 wethDepositAmount = 10e18;
    ReserveConfig memory wethConfig = _findReserveConfigBySymbol(allReservesConfigs, 'WETH');
    ReserveConfig memory ghoConfig = _findReserveConfigBySymbol(allReservesConfigs, 'GHO');
    _deposit(wethConfig, AaveV3Ethereum.POOL, ALICE, wethDepositAmount);

    // Stable borrow is deactivated
    vm.expectRevert(bytes(Errors.STABLE_BORROWING_NOT_ENABLED));
    this._borrow(ghoConfig, AaveV3Ethereum.POOL, ALICE, 1e18, true);
    vm.stopPrank();

    // Borrow as much GHO as they can
    uint256 wethPrice = AaveV3Ethereum.ORACLE.getAssetPrice(wethConfig.underlying);
    uint256 ghoPrice = AaveV3Ethereum.ORACLE.getAssetPrice(ghoConfig.underlying);
    uint256 collValue = (wethDepositAmount * wethPrice) / (10 ** wethConfig.decimals);
    uint256 borrowingPowerInGho = (((collValue * wethConfig.ltv) / 1e4) * 1e8) / ghoPrice;
    uint256 borrowableGHO = (borrowingPowerInGho * 1e18) / 1e8;
    this._borrow(ghoConfig, AaveV3Ethereum.POOL, ALICE, borrowableGHO, false);
    (, , uint256 availableToBorrow, , , ) = AaveV3Ethereum.POOL.getUserAccountData(ALICE);
    assertEq(availableToBorrow, 0);

    // Revert if borrowing more than borrowing power
    vm.expectRevert(bytes(Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW));
    this._borrow(ghoConfig, AaveV3Ethereum.POOL, ALICE, 1e18, false);
    vm.stopPrank();

    // Repay half of the borrow
    _repay(ghoConfig, AaveV3Ethereum.POOL, ALICE, borrowableGHO / 2, false);
  }
}
