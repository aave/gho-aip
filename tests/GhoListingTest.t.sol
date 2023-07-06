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
import {DataTypes} from '@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {Errors} from '@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol';
import {WadRayMath} from '@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol';

import {GovHelper} from './GovHelper.sol';
import {GhoListingPayload, Create2Helper} from '../src/contracts/GhoListingPayload.sol';
import {Helpers} from '../scripts/Helpers.sol';
import '../scripts/Constants.sol';

contract GhoListingTest is ProtocolV3TestBase {
  using stdStorage for StdStorage;

  address constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
  address public constant STKAAVE = 0x4da27a545c0c5B758a6BA100e3a049001de870f5;

  uint256 public constant FORK_BLOCK_NUMBER = 17633619;

  address public GHO_TOKEN;
  address public GHO_FLASHMINTER;

  function testListingComplete() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK_NUMBER);

    Helpers.AaveFacilitatorData memory aaveData = Helpers.deployAaveFacilitator(
      address(AaveV3Ethereum.POOL),
      VARIABLE_BORROW_RATE
    );
    address payloadAddress = Helpers.deployListingPayload(
      aaveData.ghoOracle,
      aaveData.ghoAToken,
      aaveData.ghoVariableDebtToken,
      aaveData.ghoStableDebtToken,
      aaveData.ghoInterestRateStrategy,
      aaveData.ghoDiscountRateStrategy
    );
    GhoListingPayload payload = GhoListingPayload(payloadAddress);
    GHO_TOKEN = payload.GHO_TOKEN();
    GHO_FLASHMINTER = payload.GHO_FLASHMINTER();

    // Simulate GOV action
    uint256 listingProposalId = _passProposal(AaveGovernanceV2.SHORT_EXECUTOR, address(payload));

    _testListing(address(payload), listingProposalId);
  }

  function testListingWithPayload() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK_NUMBER);
    GhoListingPayload payload = GhoListingPayload(PAYLOAD);

    // Simulate GOV action
    uint256 listingProposalId = _passProposal(AaveGovernanceV2.SHORT_EXECUTOR, address(payload));
    GHO_TOKEN = payload.GHO_TOKEN();
    GHO_FLASHMINTER = payload.GHO_FLASHMINTER();

    _testListing(address(payload), listingProposalId);
  }

  /**
   * @dev Test the payload is executed correctly even with GhoToken and GhoFlashMinter contracts already deployed.
   * This is possible due to the permissionless create2 singleton factory
   */
  function testPayloadExecutionWithContractsAlreadyDeployed() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK_NUMBER);

    Helpers.AaveFacilitatorData memory aaveData = Helpers.deployAaveFacilitator(
      address(AaveV3Ethereum.POOL),
      VARIABLE_BORROW_RATE
    );
    address payloadAddress = Helpers.deployListingPayload(
      aaveData.ghoOracle,
      aaveData.ghoAToken,
      aaveData.ghoVariableDebtToken,
      aaveData.ghoStableDebtToken,
      aaveData.ghoInterestRateStrategy,
      aaveData.ghoDiscountRateStrategy
    );
    GhoListingPayload payload = GhoListingPayload(payloadAddress);
    GHO_TOKEN = payload.GHO_TOKEN();
    GHO_FLASHMINTER = payload.GHO_FLASHMINTER();

    // Simulate GOV action
    uint256 listingProposalId = _passProposal(AaveGovernanceV2.SHORT_EXECUTOR, address(payload));

    // GhoToken deployment
    address deployedGhoToken = Create2Helper._deployCreate2(
      abi.encodePacked(type(GhoToken).creationCode, abi.encode(AaveGovernanceV2.SHORT_EXECUTOR))
    );
    // GhoFlashMinter deployment
    address deployedGhoFlashMinter = Create2Helper._deployCreate2(
      abi.encodePacked(
        type(GhoFlashMinter).creationCode,
        abi.encode(
          deployedGhoToken,
          AaveV3Ethereum.COLLECTOR,
          FLASHMINT_FEE,
          address(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER)
        )
      )
    );

    _testListing(address(payload), listingProposalId);
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
      ltv: LTV,
      liquidationThreshold: LIQUIDATION_THRESHOLD,
      liquidationBonus: LIQUIDATION_BONUS,
      liquidationProtocolFee: LIQ_PROTOCOL_FEE,
      reserveFactor: RESERVE_FACTOR,
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
      debtCeiling: DEBT_CEILING,
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
    assertTrue(
      GhoToken(GHO_TOKEN).hasRole(
        GhoToken(GHO_TOKEN).DEFAULT_ADMIN_ROLE(),
        AaveGovernanceV2.SHORT_EXECUTOR
      )
    );
    assertTrue(
      GhoToken(GHO_TOKEN).hasRole(
        GhoToken(GHO_TOKEN).FACILITATOR_MANAGER_ROLE(),
        AaveGovernanceV2.SHORT_EXECUTOR
      )
    );
    assertTrue(
      GhoToken(GHO_TOKEN).hasRole(
        GhoToken(GHO_TOKEN).BUCKET_MANAGER_ROLE(),
        AaveGovernanceV2.SHORT_EXECUTOR
      )
    );

    // Facilitators
    assertEq(IGhoToken(GHO_TOKEN).getFacilitatorsList().length, 2);

    // Aave Facilitator
    (address ghoATokenAddress, , address ghoVariableDebtTokenAddress) = AaveV3Ethereum
      .AAVE_PROTOCOL_DATA_PROVIDER
      .getReserveTokensAddresses(GHO_TOKEN);

    IGhoToken.Facilitator memory aaveFacilitator = IGhoToken(GHO_TOKEN).getFacilitator(
      ghoATokenAddress
    );
    assertEq(aaveFacilitator.label, payload.FACILITATOR_AAVE_LABEL());
    assertEq(aaveFacilitator.bucketCapacity, payload.FACILITATOR_AAVE_BUCKET_CAPACITY());
    assertEq(aaveFacilitator.bucketCapacity, FACILITATOR_AAVE_BUCKET_CAPACITY);
    assertEq(aaveFacilitator.bucketLevel, 0);
    // Reserve params
    DataTypes.ReserveData memory reserveData = IPool(address(AaveV3Ethereum.POOL)).getReserveData(
      GHO_TOKEN
    );
    assertEq(reserveData.currentLiquidityRate, 0);
    assertEq(reserveData.currentVariableBorrowRate, 0); // 0 until first interaction
    assertEq(reserveData.currentStableBorrowRate, 0);

    // IR params
    assertEq(payload.GHO_INTEREST_RATE_STRATEGY(), reserveData.interestRateStrategyAddress);
    DataTypes.CalculateInterestRatesParams memory emptyParams;
    (uint256 liqRate, uint256 stableRate, uint256 varRate) = GhoInterestRateStrategy(
      reserveData.interestRateStrategyAddress
    ).calculateInterestRates(emptyParams);
    assertEq(liqRate, 0);
    assertEq(stableRate, 0);
    assertEq(varRate, VARIABLE_BORROW_RATE);

    // GhoAToken config
    assertEq(IGhoAToken(ghoATokenAddress).getVariableDebtToken(), ghoVariableDebtTokenAddress);
    assertEq(IGhoAToken(ghoATokenAddress).getGhoTreasury(), AaveV3Ethereum.COLLECTOR);

    // GhoVariableDebtToken config
    assertEq(IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getAToken(), ghoATokenAddress);
    address discountRateStrategyAddress = IGhoVariableDebtToken(ghoVariableDebtTokenAddress)
      .getDiscountRateStrategy();
    assertEq(discountRateStrategyAddress, payload.GHO_DISCOUNT_RATE_STRATEGY());
    assertEq(IGhoVariableDebtToken(ghoVariableDebtTokenAddress).getDiscountToken(), STKAAVE);

    // DiscountRateStrategy
    assertEq(GhoDiscountRateStrategy(discountRateStrategyAddress).DISCOUNT_RATE(), DISCOUNT_RATE);
    assertEq(
      GhoDiscountRateStrategy(discountRateStrategyAddress).GHO_DISCOUNTED_PER_DISCOUNT_TOKEN(),
      GHO_DISCOUNTED_PER_DISCOUNT_TOKEN
    );
    assertEq(
      GhoDiscountRateStrategy(discountRateStrategyAddress).MIN_DISCOUNT_TOKEN_BALANCE(),
      MIN_DISCOUNT_TOKEN_BALANCE
    );
    assertEq(
      GhoDiscountRateStrategy(discountRateStrategyAddress).MIN_DEBT_TOKEN_BALANCE(),
      MIN_DEBT_TOKEN_BALANCE
    );

    // GhoOracle
    assertEq(AaveV3Ethereum.ORACLE.getSourceOfAsset(GHO_TOKEN), payload.GHO_ORACLE());
    assertEq(AaveV3Ethereum.ORACLE.getAssetPrice(GHO_TOKEN), 1e8);

    // FlashMinter
    IGhoToken.Facilitator memory flashminterFacilitator = IGhoToken(GHO_TOKEN).getFacilitator(
      GHO_FLASHMINTER
    );
    assertEq(flashminterFacilitator.label, FACILITATOR_FLASHMINTER_LABEL);
    assertEq(flashminterFacilitator.bucketCapacity, FACILITATOR_FLASHMINTER_BUCKET_CAPACITY);
    assertEq(
      flashminterFacilitator.bucketCapacity,
      payload.FACILITATOR_FLASHMINTER_BUCKET_CAPACITY()
    );
    assertEq(flashminterFacilitator.bucketLevel, 0);
    // FlashMinter params
    assertEq(GhoFlashMinter(GHO_FLASHMINTER).getFee(), 0);

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

    // Alice borrows as much GHO as they can
    uint256 wethPrice = AaveV3Ethereum.ORACLE.getAssetPrice(wethConfig.underlying);
    uint256 ghoPrice = AaveV3Ethereum.ORACLE.getAssetPrice(ghoConfig.underlying);
    uint256 collValue = (wethDepositAmount * wethPrice) / (10 ** wethConfig.decimals);
    uint256 borrowingPowerInGho = (((collValue * wethConfig.ltv) / 1e4) * 1e8) / ghoPrice;
    uint256 borrowableGHO = (borrowingPowerInGho * 1e18) / 1e8;
    this._borrow(ghoConfig, AaveV3Ethereum.POOL, ALICE, borrowableGHO, false);
    (, , uint256 availableToBorrow, , , ) = AaveV3Ethereum.POOL.getUserAccountData(ALICE);
    assertEq(availableToBorrow, 0);

    DataTypes.ReserveData memory reserveData = IPool(address(AaveV3Ethereum.POOL)).getReserveData(
      ghoConfig.underlying
    );
    assertEq(reserveData.currentVariableBorrowRate, VARIABLE_BORROW_RATE);

    // Revert if borrowing more than borrowing power
    vm.expectRevert(bytes(Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW));
    this._borrow(ghoConfig, AaveV3Ethereum.POOL, ALICE, 1e18, false);

    // Time flies (1500 blocks, with 12s blocktime)
    vm.warp(block.timestamp + 18000000);
    vm.roll(block.number + 1500000);

    // Bob borrows some GHO
    _deposit(wethConfig, AaveV3Ethereum.POOL, BOB, wethDepositAmount);
    this._borrow(ghoConfig, AaveV3Ethereum.POOL, BOB, borrowableGHO, false);

    // Alice repays half of the borrow
    _repay(ghoConfig, AaveV3Ethereum.POOL, ALICE, borrowableGHO / 10, false);

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
