// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/console2.sol';
import {Script} from 'forge-std/Script.sol';

import {AaveGovernanceV2} from 'aave-address-book/AaveGovernanceV2.sol';
import {GovHelper} from '../tests/GovHelper.sol';
import './Constants.sol';

contract SubmitAIP is Script {
  function run() external {
    uint256 deployerPrivateKey = vm.envUint('PRIVATE_KEY');
    address deployerAddress = vm.addr(deployerPrivateKey);
    console2.log('PRIVATE_KEY', deployerPrivateKey);
    console2.log('DeployerAddress', deployerAddress);
    console2.log('deployerBalance', address(deployerAddress).balance);
    console2.log('BlockNumber', block.number);

    vm.startBroadcast(deployerPrivateKey);

    bytes memory callData;
    GovHelper.ProposalParams[] memory proposalParams = new GovHelper.ProposalParams[](1);
    proposalParams[0] = GovHelper.ProposalParams({
      target: PAYLOAD,
      withDelegateCall: true,
      value: 0,
      callData: callData,
      signature: 'execute()'
    });
    uint256 proposalId = GovHelper._createProposal(
      AaveGovernanceV2.SHORT_EXECUTOR,
      IPFS_HASH,
      proposalParams
    );
    console2.log('ProposalId', proposalId);
    vm.stopBroadcast();
  }
}
