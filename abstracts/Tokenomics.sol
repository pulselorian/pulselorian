/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "../libraries/SafeMath.sol";

/**
 * @dev If I did a good job you should not need to change anything apart from the values in the `Tokenomics`,
 * the actual name of the contract `BSKR001` at the very bottom **and** the `environment` into which
 * you are deploying the contract `BSKR001(Env.Testnet)` or `BSKR001(Env.MainnetV2)` etc.
 *
 * If you wish to disable a particular tax/fee just set it to zero (or comment it out/remove it).
 *
 * You can add (in theory) as many custom taxes/fees with dedicated wallet addresses if you want.
 * Nevertheless, I do not recommend using more than a few as the contract has not been tested
 * for more than the original number of taxes/fees, which is 6 (liquidity, redistribution, burn,
 * marketing, charity & tip to the dev). Furthermore, exchanges may impose a limit on the total
 * transaction fee (so that, for example, you cannot claim 100%). Usually this is done by limiting the
 * max value of slippage, for example, PancakeSwap max slippage is 49.9% and the fees total of more than
 * 35% will most likely fail there.
 *
 * NOTE: You shouldn't really remove the Rfi fee. If you do not wish to use RFI for your token,
 * you shouldn't be using this contract at all (you're just wasting gas if you do).
 *
 * NOTE: ignore the note below (anti-whale mech is not implemented yet)
 * If you wish to modify the anti-whale mech (progressive taxation) it will require a bit of coding.
 * I tried to make the integration as simple as possible via the `Antiwhale` contract, so the devs
 * know exactly where to look and what/how to make the necessary changes. There are many possibilites,
 * such as modifying the fees based on the tx amount (as % of TOTAL_SUPPLY), or sender's wallet balance
 * (as % of TOTAL_SUPPLY), including (but not limited to):
 * - progressive taxation by tax brackets (e.g <1%, 1-2%, 2-5%, 5-10%)
 * - progressive taxation by the % over a threshold (e.g. 1%)
 * - extra fee (e.g. double) over a threshold
 */
abstract contract Tokenomics {
    using SafeMath for uint256;

    // --------------------- Token Settings ------------------- //

    string internal constant NAME = "Beskar Hands";
    string internal constant SYMBOL = "BSKRv2";

    uint16 internal constant FEES_DIVISOR = 10**3;
    uint8 internal constant DECIMALS = 6;
    uint256 internal constant ZEROES = 10**DECIMALS;

    uint256 private constant MAX = ~uint256(0);
    uint256 internal constant TOTAL_SUPPLY = 1000000000000000 * ZEROES;
    uint256 internal _reflectedSupply = (MAX - (MAX % TOTAL_SUPPLY));

    /**
     * @dev Set the maximum transaction amount allowed in a transfer.
     *
     * The default value is 10% of the total supply.
     *
     * NOTE: set the value to `TOTAL_SUPPLY` to have an unlimited max, i.e.
     * `maxTransactionAmount = TOTAL_SUPPLY;`
     */
    uint256 internal constant maxTransactionAmount = TOTAL_SUPPLY / 10; // 10% of the total supply

    /**
     * @dev Set the maximum allowed balance in a wallet.
     *
     * The default value is 25% of the total supply.
     *
     * NOTE: set the value to 0 to have an unlimited max.
     *
     * IMPORTANT: This value MUST be greater than `numberOfTokensToSwapToLiquidity` set below,
     * otherwise the liquidity swap will never be executed
     */
    uint256 internal constant maxWalletBalance = TOTAL_SUPPLY / 4; // 25% of the total supply

    /**
     * @dev Set the number of tokens to swap and add to liquidity.
     *
     * Whenever the contract's balance reaches this number of tokens, swap & liquify will be
     * executed in the very next transfer (via the `_beforeTokenTransfer`)
     *
     * If the `FeeType.Liquidity` is enabled in `FeesSettings`, the given % of each transaction will be first
     * sent to the contract address. Once the contract's balance reaches `numberOfTokensToSwapToLiquidity` the
     * `swapAndLiquify` of `Liquifier` will be executed. Half of the tokens will be swapped for ETH
     * (or BNB on BSC) and together with the other half converted into a Token-ETH/Token-BNB LP Token.
     *
     * See: `Liquifier`
     */
    uint256 internal constant numberOfTokensToSwapToLiquidity =
        TOTAL_SUPPLY / 1000; // 0.1% of the total supply

    // --------------------- Fees Settings ------------------- //

    /**
     * @dev To add/edit/remove fees scroll down to the `addFees` function below
     */

    // 0x55553eb70be81b2d4ca7c1330da90d306a615555
    address internal lotteryAddress =
        0x13D44474B125B5582A42a826035A99e38a4962A7; // notice 1077e127 similar to Lottery
    address internal marketingAddress =
        0x4F06FCcAa501B7BB9f9AFcEFb20f7862Be050B7d; // notice the 5555 pre and post fix
    address internal burnAddress = 0x000000000000000000000000000000000000dEaD;

    enum FeeType {
        Antiwhale,
        Burn,
        Liquidity,
        Rfi,
        External,
        ExternalToETH
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
        _addFee(FeeType.Liquidity, 5, address(this));
        _addFee(FeeType.External, 10, marketingAddress);
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

    // function getCollectedFeeTotal(uint256 index) external view returns (uint256){
    function getCollectedFeeTotal(uint256 index)
        internal
        view
        returns (uint256)
    {
        Fee memory fee = _getFeeStruct(index);
        return fee.total;
    }
}
