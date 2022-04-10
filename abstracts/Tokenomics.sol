/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "../libraries/SafeMath.sol";

/**
 *
 * If you wish to disable a particular tax/fee just set it to zero (or comment it out/remove it).
 *
 * Some exchanges may impose a limit on the total transaction fee (for example, cannot claim 100%).
 * Usually this is done by limiting the max value of slippage, for example, PancakeSwap max slippage
 * is 49.9% and the fees total of more than 35% will most likely fail there.
 *
 */
abstract contract Tokenomics {
    using SafeMath for uint256;

    // --------------------- Token Settings ------------------- //
    string internal constant NAME = "pulselorian.com BSKRv8";
    string internal constant SYMBOL = "BSKRv8";

    uint16 internal constant FEES_DIVISOR = 10**3;
    uint8 internal constant DECIMALS = 18;
    uint256 internal constant ZEROES = 10**DECIMALS; // 18 decimals to be standard

    uint256 private constant MAX = ~uint256(0);
    uint256 internal constant TOTAL_SUPPLY = 10**12 * ZEROES; // 1 trillion
    uint256 internal _reflectedSupply = (MAX - (MAX % TOTAL_SUPPLY));

    /**
     * @dev Set the maximum transaction amount allowed in a transfer.
     *
     * The default value is 5% of the total supply.
     *
     * NOTE: set the value to `TOTAL_SUPPLY` to have an unlimited max, i.e.
     * `maxTransactionAmount = TOTAL_SUPPLY;`
     */
    uint256 internal constant maxTransactionAmount = TOTAL_SUPPLY / 20; // 5% of the total supply

    /**
     * @dev Set the maximum allowed balance in a wallet.
     *
     * The default value is 12.5% of the total supply.
     *
     * NOTE: set the value to 0 to have an unlimited max.
     *
     * IMPORTANT: This value MUST be greater than `numberOfTokensToSwapToLiquidity` set below,
     * otherwise the liquidity swap will never be executed
     */
    uint256 internal constant maxWalletBalance = TOTAL_SUPPLY / 8; // 12.5% of the total supply

    /**
     * @dev Set the number of tokens to swap and add to liquidity.
     *
     * Whenever the contract's balance reaches this number of tokens, swap & liquify will be
     * executed in the very next transfer (via the `_beforeTokenTransfer`)
     *
     * If the `FeeType.Liquidity` is enabled in `FeesSettings`, the given % of each transaction will be first
     * sent to the contract address. Once the contract's balance reaches `numberOfTokensToSwapToLiquidity` the
     * `swapAndLiquify` of `Liquifier` will be executed. Half of the tokens will be swapped for native tokens
     * and together with the other half converted into a BSKR-NativeToken LP Token.
     *
     * See: `Liquifier`
     */
    uint256 internal constant numberOfTokensToSwapToLiquidity =
        TOTAL_SUPPLY / 1000; // 0.1% of the total supply

    // --------------------- Fees Settings ------------------- //

    /**
     * @dev To add/edit/remove fees scroll down to the `addFees` function below
     */

    // TODO change the wallet addresses before releasing to mainnet
    address internal lotteryAddress =
        0x13D44474B125B5582A42a826035A99e38a4962A7;
    address internal growthAddress = 0x4F06FCcAa501B7BB9f9AFcEFb20f7862Be050B7d;
    address internal burnAddress = 0x000000000000000000000000000000000000dEaD;

    enum FeeType {
        Burn,
        Liquidity,
        Rfi,
        External,
        ExternalToNativeToken
    }
    struct Fee {
        FeeType name;
        uint256 value;
        address recipient;
        uint256 total;
    }

    Fee[] internal fees;
    uint256 internal sumOfFees;

    constructor() {
        _addFees();
    }

    function _addFee(
        FeeType name,
        uint256 value,
        address recipient
    ) private {
        fees.push(Fee(name, value, recipient, 0));
        sumOfFees += value;
    }

    function _addFees() private {
        /**
         * The RFI recipient is ignored but we need to give a valid address value
         *
         * CAUTION: If you don't want to use RFI this implementation isn't really for you!
         *      There are much more efficient and cleaner token contracts without RFI
         *      so you should use one of those
         *
         * The value of fees is given in part per 1000 (based on the value of FEES_DIVISOR),
         * e.g. for 5% use 50, for 3.5% use 35, etc.
         */
        _addFee(FeeType.Rfi, 20, address(this));
        _addFee(FeeType.Burn, 15, burnAddress);
        _addFee(FeeType.External, 10, growthAddress);
        _addFee(FeeType.Liquidity, 5, address(this));
        _addFee(FeeType.External, 5, lotteryAddress);
    }

    function _getFeesCount() internal view returns (uint256) {
        return fees.length;
    }

    function _getFeeStruct(uint256 index) private view returns (Fee storage) {
        require(
            index >= 0 && index < fees.length,
            "FeesSettings._getFeeStruct: Fee index out of bounds"
        );
        return fees[index];
    }

    function _getFee(uint256 index)
        internal
        view
        returns (
            FeeType,
            uint256,
            address,
            uint256
        )
    {
        Fee memory fee = _getFeeStruct(index);
        return (fee.name, fee.value, fee.recipient, fee.total);
    }

    function _addFeeCollectedAmount(uint256 index, uint256 amount) internal {
        Fee storage fee = _getFeeStruct(index);
        fee.total = fee.total.add(amount);
    }

    function getCollectedFeeTotal(uint256 index)
        internal
        view
        returns (uint256)
    {
        Fee memory fee = _getFeeStruct(index);
        return fee.total;
    }
}
