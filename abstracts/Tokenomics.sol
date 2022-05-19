/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

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
    // --------------------- Token Settings ------------------- //
    string internal constant NAME = "BSKR - pulselorian.com"; // ERC20 _name
    string internal constant SYMBOL = "BSKR"; // ERC20 _symbol
    uint8 internal constant DECIMALS = 18;
    uint16 internal constant FEES_DIVISOR = 10**3;
    uint256 internal constant ZEROES = 10**DECIMALS; // 18 decimals to be standard
    uint256 private constant MAX = ~uint256(0);
    uint256 internal constant TOTAL_SUPPLY = 10**12 * ZEROES; // 1 trillion
    uint256 internal _reflectedSupply = (MAX - (MAX % TOTAL_SUPPLY));
    uint256 internal constant maxTransactionAmount = TOTAL_SUPPLY / 25; // 4% of the total supply
    uint256 internal constant maxWalletBalance = TOTAL_SUPPLY / 5; // 20% of the total supply
    uint256 internal constant numberOfTokensToSwapToLiquidity =
        TOTAL_SUPPLY / 2000; // 0.05% of the total supply
    address internal paydayAddress = 0x13D44474B125B5582A42a826035A99e38a4962A7; // TODO change before release
    address internal growthAddress = 0x4F06FCcAa501B7BB9f9AFcEFb20f7862Be050B7d; // TODO change before release
    address internal burnAddress = 0x000000000000000000000000000000000000dEaD;

    // to reduce centralized risk
    // in addition to owner, the BSKR funds can be spread into these wallets
    address[] internal sisterOAs = [
        address(0x000000015d3638A850B12D1D3FcF284B5DD529d5),
        0x00000010A0eD61306747B4CA7A11D42A84855832,
        0x000000146E609e2eB40346c668a17Fc32AA4Bd7c,
        0x00000016a0c2035799f0e3f14184C65AcBD71892,
        0x000000180803CDb49fb17a098338AF68FfB83136
    ];

    // // to reduce centralized risk
    // address[5] internal lpOwners = [
    //     address(0x00000019e5Ba0A187e48B067B2a0899E712343C7),
    //     0x000000230Dd8231722989D56E6A0270061E83b8f,
    //     0x00000023b7892d99c3bd7F51465f9514ED9b82f6,
    //     0x0000004fBdA7D073a89DBd313d5F7b8a3cdF3903,
    //     0x00000059f72E9b2197912b7aFedf3eB2278A4cDA
    // ];

    // --------------------- Fees Settings ------------------- //

    enum FeeType {
        Burn,
        Liquidity,
        Rfi,
        External
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
        _addFee(FeeType.External, 5, paydayAddress);
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
        fee.total = fee.total + amount;
    }
}
