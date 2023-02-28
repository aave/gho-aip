# Aave GHO AIP

## Setup

```sh
cp .env.example .env
forge install
```

```sh
forge build
```

### Test

```sh
forge test -vvvv
```


## Development

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for detailed instructions on how to install and use Foundry.
The template ships with sensible default so you can use default `foundry` commands without resorting to `MakeFile`.


## Advanced features

### Diffing

For contracts upgrading implementations it's quite important to diff the implementation code to spot potential issues and ensure only the intended changes are included.
Therefore the `Makefile` includes some commands to streamline the diffing process.

#### Download

You can `download` the current contract code of a deployed contract via `make download chain=polygon address=0x00`. This will download the contract source for specified address to `src/etherscan/chain_address`. This command works for all chains with a etherscan compatible block explorer.

#### Git diff

You can `git-diff` a downloaded contract against your src via `make git-diff before=./etherscan/chain_address after=./src out=filename`. This command will diff the two folders via git patience algorithm and write the output to `diffs/filename.md`.

**Caveat**: If the onchain implementation was verified using flatten, for generating the diff you need to flatten the new contract via `forge flatten` and supply the flattened file instead fo the whole `./src` folder.


#### Deploying
Deploy Oracle
forge script scripts/DeployGhoOracle.s.sol:Deploy --fork-url https://rpc.tenderly.co/fork/09f4bf7f-0ba5-4152-8c2f-cee5fbf620f6 --broadcast -- --vvvv

Deploy AToken
forge script scripts/DeployGhoAToken.s.sol:Deploy --fork-url https://rpc.tenderly.co/fork/09f4bf7f-0ba5-4152-8c2f-cee5fbf620f6 --broadcast -- --vvvv

Deploy GhoToken
forge script scripts/DeployGhoToken.s.sol:Deploy --fork-url https://rpc.tenderly.co/fork/09f4bf7f-0ba5-4152-8c2f-cee5fbf620f6 --broadcast -- --vvvv


Deploy GhoInterstStrategy
forge script scripts/DeployGhoInterestStrategy.s.sol:Deploy --fork-url https://rpc.tenderly.co/fork/09f4bf7f-0ba5-4152-8c2f-cee5fbf620f6 --broadcast -- --vvvv


Deploy GhoVariableDebtToken
forge script scripts/DeployGhoVariableDebtToken.s.sol:Deploy --fork-url https://rpc.tenderly.co/fork/09f4bf7f-0ba5-4152-8c2f-cee5fbf620f6 --broadcast -- --vvvv