// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {ProtocolV3TestBase, ReserveConfig, ReserveTokens} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GhoToken} from 'gho-core/gho/GhoToken.sol';
import {IGhoToken} from 'gho-core/gho/interfaces/IGhoToken.sol';
import {GhoOracle} from 'gho-core/facilitators/aave/oracle/GhoOracle.sol';
import {GhoAToken} from 'gho-core/facilitators/aave/tokens/GhoAToken.sol';
import {IGhoAToken} from 'gho-core/facilitators/aave/tokens/interfaces/IGhoAToken.sol';
import {GhoFlashMinter} from 'gho-core/facilitators/flashMinter/GhoFlashMinter.sol';
import {GhoVariableDebtToken} from 'gho-core/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {GhoStableDebtToken} from 'gho-core/facilitators/aave/tokens/GhoStableDebtToken.sol';
import {IGhoVariableDebtToken} from 'gho-core/facilitators/aave/tokens/interfaces/IGhoVariableDebtToken.sol';
import {GhoInterestRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {GhoDiscountRateStrategy} from 'gho-core/facilitators/aave/interestStrategy/GhoDiscountRateStrategy.sol';
import {AggregatedStakedAaveV3} from 'aave-stk-v1-5/interfaces/AggregatedStakedAaveV3.sol';
import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';

import {GovHelper} from './GovHelper.sol';
import {GhoListingPayload} from '../src/contracts/GhoListingPayload.sol';

contract GhoListingTest is ProtocolV3TestBase {
  using stdStorage for StdStorage;

  address constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
  address public constant STKAAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;

  address public constant STKAAVE_UPGRADE_PAYLOAD = 0xe427FCbD54169136391cfEDf68E96abB13dA87A0; // AIP#124
  uint256 public constant STKAAVE_UPGRADE_BLOCK_NUMBER = 17138206;

  bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
  bytes32 public constant FACILITATOR_MANAGER = keccak256('FACILITATOR_MANAGER');
  bytes32 public constant BUCKET_MANAGER = keccak256('BUCKET_MANAGER');

  address public GHO_TOKEN;
  address public GHO_FLASHMINTER;

  function testListingComplete() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), STKAAVE_UPGRADE_BLOCK_NUMBER);
    GhoToken ghoToken = new GhoToken(AaveGovernanceV2.SHORT_EXECUTOR);

    GhoListingPayload payload = new GhoListingPayload(
      address(new GhoOracle()),
      address(new GhoAToken(IPool(address(AaveV3Ethereum.POOL)))),
      address(new GhoVariableDebtToken(IPool(address(AaveV3Ethereum.POOL)))),
      address(new GhoStableDebtToken(IPool(address(AaveV3Ethereum.POOL)))),
      address(new GhoInterestRateStrategy(0.0250e27)), // 2.5% in ray
      address(new GhoDiscountRateStrategy())
    );
    GHO_TOKEN = payload.precomputeGhoTokenAddress();
    GHO_FLASHMINTER = payload.precomputeGhoFlashMinterAddress();

    // Simulate stkAave upgrade
    uint256 upgradeProposalId = _passProposal(
      AaveGovernanceV2.LONG_EXECUTOR,
      STKAAVE_UPGRADE_PAYLOAD
    );
    GovHelper._execute(upgradeProposalId);

    // Simulate GOV action
    uint256 listingProposalId = _passProposal(AaveGovernanceV2.SHORT_EXECUTOR, address(payload));

    _testListing(address(payload), listingProposalId);
  }

  function _testListingWithPayload() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), STKAAVE_UPGRADE_BLOCK_NUMBER);
    address GHO_AIP = address(0); // TODO

    // Simulate stkAave upgrade
    uint256 upgradeProposalId = _passProposal(
      AaveGovernanceV2.LONG_EXECUTOR,
      STKAAVE_UPGRADE_PAYLOAD
    );
    GovHelper._execute(upgradeProposalId);

    // Simulate GOV action
    uint256 listingProposalId = _passProposal(AaveGovernanceV2.SHORT_EXECUTOR, GHO_AIP);

    _testListing(GHO_AIP, listingProposalId);
  }

  function _testListing(address payloadAddress, uint256 proposalId) internal {
    GhoListingPayload payload = GhoListingPayload(payloadAddress);

    ReserveConfig[] memory allConfigsBefore = _getReservesConfigs(AaveV3Ethereum.POOL);

    createConfigurationSnapshot('preTestEngineListing', AaveV3Ethereum.POOL);

    GovHelper._execute(proposalId);

    createConfigurationSnapshot('postTestEngineListing', AaveV3Ethereum.POOL);

    diffReports('preTestEngineListing', 'postTestEngineListing');

    ReserveConfig[] memory allConfigsAfter = _getReservesConfigs(AaveV3Ethereum.POOL);

    ReserveConfig memory expectedAssetConfig = ReserveConfig({
      symbol: 'GHO',
      underlying: GHO_TOKEN,
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
      GHO_TOKEN,
      payload.GHO_ORACLE()
    );

    _validateGhoConfigurationPostProposal(payload);
    _validateGhoActionsPostProposal(allConfigsAfter);
  }

  function _passProposal(address executor, address payload) internal returns (uint256) {
    deal(AAVE, address(this), 2_000_000e18);
    bytes memory callData;
    GovHelper.ProposalParams[] memory proposalParams = new GovHelper.ProposalParams[](1);
    proposalParams[0] = GovHelper.ProposalParams({
      target: payload,
      withDelegateCall: true,
      value: 0,
      callData: callData,
      signature: 'execute()'
    });
    uint256 proposalId = GovHelper._createProposal(executor, bytes32(0), proposalParams);

    (uint256 startBlock, uint256 endBlock, ) = GovHelper._getProposal(proposalId);

    // vote
    vm.roll(startBlock + 1);
    GovHelper._vote(proposalId);

    // queue
    vm.roll(endBlock + 1);
    GovHelper._queue(proposalId);

    // get ready to execute
    (, , uint256 executionTime) = GovHelper._getProposal(proposalId);
    vm.warp(executionTime);

    return proposalId;
  }

  function _validateGhoConfigurationPostProposal(GhoListingPayload payload) internal {
    // GHO
    assertEq(IGhoToken(GHO_TOKEN).totalSupply(), 0);
    assertTrue(GhoToken(GHO_TOKEN).hasRole(DEFAULT_ADMIN_ROLE, AaveGovernanceV2.SHORT_EXECUTOR));

    // Facilitators
    assertEq(IGhoToken(GHO_TOKEN).getFacilitatorsList().length, 2);

    // Aave Facilitator
    (address ghoATokenAddress, , address ghoVariableDebtTokenAddress) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveTokensAddresses(GHO_TOKEN);

    (uint256 aaveCapacity, uint256 aaveLevel) = IGhoToken(GHO_TOKEN).getFacilitatorBucket(
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
    assertEq(IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getDiscountToken(), STKAAVE);

    // GhoOracle
    assertEq(AaveV3Ethereum.ORACLE.getSourceOfAsset(GHO_TOKEN), payload.GHO_ORACLE());
    assertEq(AaveV3Ethereum.ORACLE.getAssetPrice(GHO_TOKEN), 1e8);

    // FlashMinter
    (uint256 flashMinterCapacity, uint256 flashMinterLevel) = IGhoToken(GHO_TOKEN)
      .getFacilitatorBucket(GHO_FLASHMINTER);
    assertEq(flashMinterCapacity, payload.FACILITATOR_FLASHMINTER_BUCKET_CAPACITY());
    assertEq(flashMinterLevel, 0);

    // StkAAVE
    assertEq(AggregatedStakedAaveV3(STKAAVE).ghoDebtToken(), ghoVariableDebtTokenAddress);
  }

  function _validateGhoActionsPostProposal(ReserveConfig[] memory allReservesConfigs) internal {
    address ALICE = address(0x111);
    address BOB = address(0x222);

    // Alice supplies some collateral
    uint256 wethDepositAmount = 10e18;
    ReserveConfig memory wethConfig = _findReserveConfigBySymbol(allReservesConfigs, 'WETH');
    ReserveConfig memory ghoConfig = _findReserveConfigBySymbol(allReservesConfigs, 'GHO');
    _deposit(wethConfig, AaveV3Ethereum.POOL, ALICE, wethDepositAmount);

    // Stable borrow is deactivated
    vm.expectRevert(bytes(Errors.STABLE_BORROWING_NOT_ENABLED));
    this._borrow(ghoConfig, AaveV3Ethereum.POOL, ALICE, 1e18, true);
    vm.stopPrank();

    // Alice borrows as much GHO as they can
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

    // Time flies (1500 blocks, with 12s blocktime)
    vm.warp(block.timestamp + 18000000);
    vm.roll(block.number + 1500000);

    // Bob borrows some GHO
    _deposit(wethConfig, AaveV3Ethereum.POOL, BOB, wethDepositAmount);
    this._borrow(ghoConfig, AaveV3Ethereum.POOL, BOB, borrowableGHO, false);

    // Alice repays half of the borrow
    _repay(ghoConfig, AaveV3Ethereum.POOL, ALICE, borrowableGHO / 2, false);

    // Bob receives 1000 stkAave and get a discount
    (, , address ghoVariableDebtTokenAddress) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveTokensAddresses(ghoConfig.underlying);

    assertEq(IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getDiscountPercent(BOB), 0);
    assertEq(AggregatedStakedAaveV3(STKAAVE).balanceOf(BOB), 0);
    deal(STKAAVE, ALICE, 1_000_000e18);
    vm.prank(ALICE);
    AggregatedStakedAaveV3(STKAAVE).transfer(BOB, 1e18);

    uint256 newDiscountPercent = _calcDiscountPercent(
      ghoVariableDebtTokenAddress,
      borrowableGHO,
      1e18
    );
    assertEq(
      IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getDiscountPercent(BOB),
      newDiscountPercent
    );
    assertEq(AggregatedStakedAaveV3(STKAAVE).balanceOf(BOB), 1e18);

    // Bob receives 0.5M stkAave and get maximum discount
    vm.prank(ALICE);
    AggregatedStakedAaveV3(STKAAVE).transfer(BOB, 500_000e18);
    newDiscountPercent = _calcDiscountPercent(
      ghoVariableDebtTokenAddress,
      borrowableGHO,
      500_001e18
    );
    assertEq(
      IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getDiscountPercent(BOB),
      newDiscountPercent
    );
    assertEq(AggregatedStakedAaveV3(STKAAVE).balanceOf(BOB), 500_001e18);
  }

  function _calcDiscountPercent(
    address ghoVariableDebtTokenAddress,
    uint256 debtBalance,
    uint256 discountTokenBalance
  ) internal view returns (uint256) {
    address ghoDiscountRateStrategy = IGhoVariableDebtToken(ghoVariableDebtTokenAddress)
      .getDiscountRateStrategy();

    uint256 ghoDiscountedPerDiscountToken = GhoDiscountRateStrategy(ghoDiscountRateStrategy)
      .GHO_DISCOUNTED_PER_DISCOUNT_TOKEN();
    uint256 discountedBalance = WadRayMath.wadMul(
      discountTokenBalance,
      ghoDiscountedPerDiscountToken
    );
    if (discountedBalance >= debtBalance) {
      return GhoDiscountRateStrategy(ghoDiscountRateStrategy).DISCOUNT_RATE();
    } else {
      return
        (discountedBalance * GhoDiscountRateStrategy(ghoDiscountRateStrategy).DISCOUNT_RATE()) /
        debtBalance;
    }
  }
}
