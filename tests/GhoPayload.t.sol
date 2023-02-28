// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console.sol';

import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GhoAToken} from 'gho-core/src/contracts/facilitators/aave/tokens/GhoAToken.sol';
import {GhoOracle} from 'gho-core/src/contracts/facilitators/aave/oracle/GhoOracle.sol';
import {GhoToken} from 'gho-core/src/contracts/gho/GhoToken.sol';
import {GhoInterestRateStrategy} from 'gho-core/src/contracts/facilitators/aave/interestStrategy/GhoInterestRateStrategy.sol';
import {GhoVariableDebtToken} from 'gho-core/src/contracts/facilitators/aave/tokens/GhoVariableDebtToken.sol';
import {ProtocolV3_0_1TestBase, ReserveConfig, ReserveTokens} from 'aave-helpers/src/ProtocolV3TestBase.sol';
import {GhoListingPayload} from '../src/contracts/GhoAIP.sol';

// import {IPoolConfigurator, ConfiguratorInputTypes} from 'aave-address-book/AaveV3.sol';

import {TestWithExecutor} from 'aave-helpers/src/GovHelpers.sol';

contract AaveV3EthGhoUSDPayloadTest is ProtocolV3_0_1TestBase, TestWithExecutor {
  using stdStorage for StdStorage;

  // address public constant GHO_TOKEN = 0xfd7dF17EF5Baa6460204D95B4F00e355e5B77544;
  // uint8 public constant GHO_DECIMALS = 18;

  // address public constant GHO_ORACLE = 0x4Cfed366cfD75Ec739e0d763f557680Bc656a965;

  // address public constant GHO_ATOKEN = 0x946541093fC2dE445161dD0A67b8524d1FBc5428;
  // address public constant GHO_VARIABLE_DEBT_TOKEN = 0x5B3f652d1B8e9D28F351DCE75993eD4d6Efc3F78;

  // address public constant ATOKEN_IMPL = 0x946541093fC2dE445161dD0A67b8524d1FBc5428;
  // address public constant VARIABLE_DEBT_IMPL = 0x5B3f652d1B8e9D28F351DCE75993eD4d6Efc3F78;
  // address public constant STABLE_DEBT_IMPL = 0x595c33538215DC4B092F35Afc85d904631263f4F;
  // address public constant INTEREST_RATE_STRATEGY = 0xcA20515e8fB92Ec70eaDa5c0Ad5A502bCab1B2E0;

  // string public constant ATOKEN_NAME = 'Aave Ethereum GHO';
  // string public constant ATOKEN_SYMBOL = 'aEthGHO';
  // string public constant VDTOKEN_NAME = 'Aave Ethereum Variable Debt GHO';
  // string public constant VDTOKEN_SYMBOL = 'variableDebtEthGHO';
  // string public constant SDTOKEN_NAME = 'Aave Ethereum Stable Debt GHO';
  // string public constant SDTOKEN_SYMBOL = 'stableDebtEthGHO';

  // uint256 public constant RESERVE_FACTOR = 1000;
  // uint256 public constant LTV = 0;
  // uint256 public constant LIQUIDATION_THRESHOLD = 0;
  // uint256 public constant LIQUIDATION_BONUS = 0;

  // the identifiers of the forks
  uint256 mainnetFork;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 16721514);
    _selectPayloadExecutor(AaveGovernanceV2.SHORT_EXECUTOR);
  }

  function testExecute() public {
    GhoAToken ghoAtoken = new GhoAToken(AaveV3Ethereum.POOL);

    GhoOracle ghoOracle = new GhoOracle();

    GhoToken ghoToken = new GhoToken();

    GhoVariableDebtToken ghoVariableDebtToken = new GhoVariableDebtToken(AaveV3Ethereum.POOL);

    GhoInterestRateStrategy ghoInterestRateStrategy = new GhoInterestRateStrategy(25); // variable borrow rate expressed in ray

    GhoListingPayload ghoAip = new GhoListingPayload(
      address(ghoAtoken),
      // address('0x0000000000000000000000000000000000000000'),
      address(ghoVariableDebtToken),
      address(ghoInterestRateStrategy),
      address(ghoToken)
    );

    vm.startPrank(AaveV3Ethereum.ACL_ADMIN);
    AaveV3Ethereum.ACL_MANAGER.addPoolAdmin(address(ghoAip));
    vm.stopPrank();

    ReserveConfig[] memory allConfigsBefore = _getReservesConfigs(AaveV3Ethereum.POOL);

    createConfigurationSnapshot('preGhoUSD', AaveV3Ethereum.POOL);
    ghoAip.execute();

    console.log('ghoAIP address', address(ghoAip));
    console.log('ghoOracle address', address(ghoOracle));

    ReserveConfig[] memory allConfigsAfter = _getReservesConfigs(AaveV3Ethereum.POOL);

    //  ReserveConfig memory expectedAssetConfig = ReserveConfig({
    //   symbol: 'GHO',
    //   underlying: GHO_TOKEN,
    //   aToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
    //   variableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
    //   stableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
    //   decimals: GHO_DECIMALS,
    //   ltv: LTV,
    //   liquidationThreshold: LIQUIDATION_THRESHOLD,
    //   liquidationBonus: LIQUIDATION_BONUS,
    //   liquidationProtocolFee: 10_00,
    //   reserveFactor: RESERVE_FACTOR,
    //   usageAsCollateralEnabled: true,
    //   borrowingEnabled: true,
    //   interestRateStrategy: _findReserveConfigBySymbol(allConfigsAfter, '1INCH')
    //     .interestRateStrategy,
    //   stableBorrowRateEnabled: false,
    //   isActive: true,
    //   isFrozen: false,
    //   isSiloed: false,
    //   isBorrowableInIsolation: false,
    //   isFlashloanable: false,
    //   supplyCap: 85_000,
    //   borrowCap: 60_000,
    //   debtCeiling: 0,
    //   eModeCategory: 0
    // });

    // assert(true);
    // assertEq(true, true);
  }
}
