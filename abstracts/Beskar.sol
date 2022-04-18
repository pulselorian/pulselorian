/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "./LotteryRfiToken.sol";

abstract contract Beskar is LotteryRfiToken {
    address[] private _LPpairs;
    uint256 private pairCountChecked = 0;

    constructor(Env _env) {
        initializeLiquiditySwapper(
            _env,
            maxTransactionAmount,
            numberOfTokensToSwapToLiquidity
        );

        // exclude the pair address from rewards - we don't want to redistribute
        // tx fees to these two; redistribution is only for holders, dah!
        _excludeFromRewards(_pair);
        _excludeFromRewards(burnAddress);
    }

    function _isV2Pair(address account) internal view override returns (bool) {
        bool isLPpair = (account == _pair);
        for (uint256 i = 0; i < _LPpairs.length && !isLPpair; i++) {
            if (_LPpairs[i] == account) {
                isLPpair = true;
            }
        }

        return isLPpair;
    }

    /**
     * @dev Before the token transfer call liquify which checks balance against
     * threshold and adds liquidity if eligible
     */
    function _beforeTokenTransfer(
        address sender,
        address,
        uint256,
        bool
    ) internal override {
        uint256 contractTokenBalance = balanceOf(address(this));
        liquify(contractTokenBalance, sender);
        addLPPairs();
    }

    function addLPPairs() internal {
        uint256 allPairsCount = _factory.allPairsLength();

        if (pairCountChecked < allPairsCount) {
            // new pairs added since last check

            for (uint256 i = pairCountChecked; i < allPairsCount; i++) {
                address pairAddress = _factory.allPairs(i);
                IPancakePair pairC = IPancakePair(pairAddress);
                if (
                    pairC.token0() == address(this) ||
                    pairC.token1() == address(this)
                ) {
                    _LPpairs.push(pairAddress);
                    _excludeFromRewards(pairAddress);
                }
            }

            pairCountChecked = allPairsCount;
        }
    }

    /**
     * @dev Depending on the fee type, take appropriate action
     * redistribute reflection fee, burn the burn fee amount, etc.
     */
    function _takeTransactionFees(uint256 amount, uint256 currentRate)
        internal
        override
    {
        uint256 feesCount = _getFeesCount();
        for (uint256 index = 0; index < feesCount; index++) {
            (FeeType name, uint256 value, address recipient, ) = _getFee(index);
            // no need to check value < 0 as the value is uint (i.e. from 0 to 2^256-1)
            if (value == 0) continue;

            if (name == FeeType.Rfi) {
                _redistribute(amount, currentRate, value, index);
            } else if (name == FeeType.Burn) {
                _burn(amount, currentRate, value, index);
            } else if (name == FeeType.ExternalToNativeToken) {
                _takeFeeToNativeToken(
                    amount,
                    currentRate,
                    value,
                    recipient,
                    index
                );
            } else {
                _takeFee(amount, currentRate, value, recipient, index);
            }
        }
    }

    /**
     * @dev Burns the amount of tokens specified
     */
    function _burn(
        uint256 amount,
        uint256 currentRate,
        uint256 fee,
        uint256 index
    ) private {
        uint256 tBurn = (amount * fee) / FEES_DIVISOR;
        uint256 rBurn = tBurn * currentRate;

        _burnTokens(address(this), tBurn, rBurn);
        _addFeeCollectedAmount(index, tBurn);
    }

    /**
     * @dev Calculates the fees amount
     */
    function _takeFee(
        uint256 amount,
        uint256 currentRate,
        uint256 fee,
        address recipient,
        uint256 index
    ) private {
        uint256 tAmount = (amount * fee) / FEES_DIVISOR;
        uint256 rAmount = tAmount * currentRate;

        _reflectedBalances[recipient] = _reflectedBalances[recipient] + rAmount;
        if (_isExcludedFromRewards[recipient])
            _balances[recipient] = _balances[recipient] + tAmount;

        _addFeeCollectedAmount(index, tAmount);
    }

    /**
     * @dev When implemented this will convert the fee amount of BSKR into native tokens
     * and send to the recipient's wallet. Note that this reduces liquidity so it
     * might be a good idea to add a % into the liquidity fee for % you take our through
     * this method (just a suggestion)
     */
    function _takeFeeToNativeToken(
        uint256 amount,
        uint256 currentRate,
        uint256 fee,
        address recipient,
        uint256 index
    ) private {
        _takeFee(amount, currentRate, fee, recipient, index);
    }

    function _approveDelegate(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        _approve(owner, spender, amount);
    }

    // TODO do we really need this function?
    function burntBSKRBalance() external view returns (uint256) {
        return _balances[burnAddress];
    }
}
