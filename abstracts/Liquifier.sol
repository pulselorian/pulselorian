/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "./Manageable.sol";
import "../interfaces/IPancakeV2Router.sol";
import "../interfaces/IPancakeV2Factory.sol";

abstract contract Liquifier is Manageable {
    uint256 private withdrawableBalance;

    enum Env {
        BSCTestnet,
        BSCMainnetV1,
        BSCMainnetV2,
        PLSTestnetv2b
    }
    Env private _env;

    // PancakeSwap V1
    address private _bscMainnetV1RouterAddress =
        0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F;
    // PancakeSwap V2
    address private _bscMainnetV2RouterAddress =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;
    // Testnet
    // address private _testnetRouterAddress = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
    // PancakeSwap Testnet = https://pancake.kiemtienonline360.com/
    // https://amm.kiemtienonline360.com/#BSC
    address private _bscTestnetRouterAddress =
        0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
    address private _plsTestnetv2bRouterAddress =
        0xb4A7633D8932de086c9264D5eb39a8399d7C0E3A;

    IPancakeV2Router internal _router;
    IPancakeV2Factory internal _factory;
    address internal _pair;

    bool private inSwapAndLiquify;
    bool private swapAndLiquifyEnabled = true;

    uint256 private maxTransactionAmount;
    uint256 private numberOfTokensToSwapToLiquidity;

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    event RouterSet(address indexed router);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 nativeTokensReceived,
        uint256 tokensIntoLiquidity
    );
    event LiquidityAdded(
        uint256 tokenAmountSent,
        uint256 nativeTokenAmountSent,
        uint256 liquidity
    );

    receive() external payable {}

    function initializeLiquiditySwapper(
        Env env,
        uint256 maxTx,
        uint256 liquifyAmount
    ) internal {
        _env = env;
        if (_env == Env.BSCMainnetV1) {
            _setRouterAddress(_bscMainnetV1RouterAddress);
        } else if (_env == Env.BSCMainnetV2) {
            _setRouterAddress(_bscMainnetV2RouterAddress);
        } else if (_env == Env.BSCTestnet) {
            _setRouterAddress(_bscTestnetRouterAddress);
        } else {
            // (_env == Env.PLSTestnetv2b)
            _setRouterAddress(_plsTestnetv2bRouterAddress);
        }

        maxTransactionAmount = maxTx;
        numberOfTokensToSwapToLiquidity = liquifyAmount;
    }

    /**
     * NOTE: passing the `contractTokenBalance` here is preferred to creating `balanceOfDelegate`
     */
    function liquify(uint256 contractTokenBalance, address sender) internal {
        if (contractTokenBalance >= maxTransactionAmount)
            contractTokenBalance = maxTransactionAmount;

        bool isOverRequiredTokenBalance = (contractTokenBalance >=
            numberOfTokensToSwapToLiquidity);

        /**
         * - first check if the contract has collected enough tokens to swap and liquify
         * - then check swap and liquify is enabled
         * - then make sure not to get caught in a circular liquidity event
         * - finally, don't swap & liquify if the sender is the uniswap pair
         */
        if (
            isOverRequiredTokenBalance &&
            swapAndLiquifyEnabled &&
            !inSwapAndLiquify &&
            (sender != _pair)
        ) {
            _swapAndLiquify(contractTokenBalance);
        }
    }

    /**
     * @dev sets the router address and created the router, factory pair to enable
     * swapping and liquifying (contract) tokens
     */
    function _setRouterAddress(address router) private {
        IPancakeV2Router _newPancakeRouter = IPancakeV2Router(router);
        _factory = IPancakeV2Factory(_newPancakeRouter.factory());
        _pair = _factory.createPair(
            address(this),
            _newPancakeRouter.WPLS()
            // _newPancakeRouter.WETH()
        );
        _router = _newPancakeRouter;
        emit RouterSet(router);
    }

    function _swapAndLiquify(uint256 amount) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = amount / 2;
        uint256 otherHalf = amount - half;

        // capture the contract's current native token balance.
        // this is so that we can capture exactly the amount of native tokens that the
        // swap creates, and not make the liquidity event include any native tokens that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for native token
        _swapTokensForNativeTokens(half); // <- this breaks the Native token -> HATE swap when swap+liquify is triggered

        // how much native token did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        _addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _swapTokensForNativeTokens(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> wrapped native token
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WPLS();
        // path[1] = _router.WETH();

        _approveDelegate(address(this), address(_router), tokenAmount);

        // make the swap
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            // The minimum amount of output tokens that must be received for the transaction not to revert.
            // 0 = accept any amount (slippage is inevitable)
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 nativeTokenAmount)
        private
    {
        // approve token transfer to cover all possible scenarios
        _approveDelegate(address(this), address(_router), tokenAmount);

        // add tahe liquidity
        (
            uint256 tokenAmountSent,
            uint256 nativeTokenAmountSent,
            uint256 liquidity
        ) = _router.addLiquidityETH{value: nativeTokenAmount}(
                address(this),
                tokenAmount,
                // Bounds the extent to which the Wrapped native token/token price can go up before the transaction reverts.
                // Must be <= amountTokenDesired; 0 = accept any amount (slippage is inevitable)
                0,
                // Bounds the extent to which the token/Wrapped native token price can go up before the transaction reverts.
                // 0 = accept any amount (slippage is inevitable)
                0,
                // this is a centralized risk if the owner's account is ever compromised (see Certik SSL-04)
                // owner(),
                address(this),
                block.timestamp
            );

        // fix the forever locked native token as per the Safemoon's certik audit
        /**
         * The swapAndLiquify function converts half of the contractTokenBalance BSKR tokens to native tokens.
         * For every swapAndLiquify function call, a small amount of native tokens remains in the contract.
         * This amount grows over time with the swapAndLiquify function being called throughout the life
         * of the contract. The Safemoon contract does not contain a method to withdraw these funds,
         * and the native token will be locked in the Safemoon contract forever.
         */
        withdrawableBalance = address(this).balance;
        emit LiquidityAdded(tokenAmountSent, nativeTokenAmountSent, liquidity);
    }

    /**
     * @dev Sets the uniswapV2 pair (router & factory) for swapping and liquifying tokens
     */
    function setRouterAddress(address router) external onlyManager {
        _setRouterAddress(router);
    }

    /**
     * @dev The owner can withdraw native token collected in the contract from `swapAndLiquify`
     * or if someone (accidentally) sends native token directly to the contract.
     *
     * Note: Fix for Safemoon contract flaw pointed out in the Certik Audit (SSL-03):
     *
     * The swapAndLiquify function converts half of the contractTokenBalance BSKR tokens to native token.
     * For every swapAndLiquify function call, a small amount of native token remains in the contract.
     * This amount grows over time with the swapAndLiquify function being called
     * throughout the life of the contract. The BSKR contract does not contain a method
     * to withdraw these funds, and the native token will be locked in the BSKR contract forever.
     *
     */
    function withdrawLockedNativeTokens(address payable recipient)
        external
        onlyManager
    {
        require(
            recipient != address(0),
            "Cannot withdraw the native token balance to the zero address"
        );
        require(
            withdrawableBalance > 0,
            "The native token balance must be greater than 0"
        );

        // prevent re-entrancy attacks
        uint256 amount = withdrawableBalance;
        withdrawableBalance = 0;
        recipient.transfer(amount);
    }

    /**
     * @dev Use this delegate instead of having (unnecessarily) extend `LotteryRfiToken` to gained access
     * to the `_approve` function.
     */
    function _approveDelegate(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual;
}
