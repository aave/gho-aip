// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveGovernanceV2, IAaveGovernanceV2, IExecutorWithTimelock} from 'aave-address-book/AaveGovernanceV2.sol';

library GovHelper {
  struct ProposalParams {
    address target;
    bool withDelegateCall;
    uint256 value;
    bytes callData;
    string signature;
  }

  function _getProposal(
    uint256 proposalId
  ) internal view returns (uint256 startBlock, uint256 endBlock, uint256 executionTime) {
    IAaveGovernanceV2.ProposalWithoutVotes memory proposal = AaveGovernanceV2.GOV.getProposalById(
      proposalId
    );
    startBlock = proposal.startBlock;
    endBlock = proposal.endBlock;
    executionTime = proposal.executionTime;
  }

  function _createProposal(
    address executor,
    bytes32 ipfsHash,
    ProposalParams[] memory proposalParams
  ) internal returns (uint256) {
    require(proposalParams.length > 0, 'WRONG_PROPOSAL_PARAMS');

    address[] memory targets = new address[](proposalParams.length);
    uint256[] memory values = new uint256[](proposalParams.length);
    string[] memory signatures = new string[](proposalParams.length);
    bytes[] memory calldatas = new bytes[](proposalParams.length);
    bool[] memory withDelegatecalls = new bool[](proposalParams.length);

    for (uint256 i; i < proposalParams.length; i++) {
      targets[i] = proposalParams[i].target;
      values[i] = proposalParams[i].value;
      calldatas[i] = proposalParams[i].callData;
      signatures[i] = proposalParams[i].signature;
      withDelegatecalls[i] = proposalParams[i].withDelegateCall;
    }

    return
      AaveGovernanceV2.GOV.create(
        IExecutorWithTimelock(executor),
        targets,
        values,
        signatures,
        calldatas,
        withDelegatecalls,
        ipfsHash
      );
  }

  function _vote(uint256 proposalId) internal {
    AaveGovernanceV2.GOV.submitVote(proposalId, true);
  }

  function _queue(uint256 proposalId) internal {
    AaveGovernanceV2.GOV.queue(proposalId);
  }

  function _execute(uint256 proposalId) internal {
    AaveGovernanceV2.GOV.execute(proposalId);
  }
}
