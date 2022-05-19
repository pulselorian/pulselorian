/*
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "../uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "../interfaces/IAirdrop.sol";
import "./Liquifier.sol";
import "./Tokenomics.sol";

abstract contract PaydayRfiToken is
    IERC20Metadata,
    Tokenomics,
    Liquifier,
    IAirdrop
{
    using Address for address;

    mapping(address => uint256) internal _balances; // ERC20
    mapping(address => mapping(address => uint256)) internal _allowances; // ERC20

    mapping(address => uint256) internal _reflectedBalances;
    mapping(address => bool) internal _isExcludedFromFee;
    mapping(address => bool) internal _isExcludedFromRewards;

    address[] private _excludedFromRewards;

    uint8 internal oaIndex = 0;
    
    constructor() {
        _reflectedBalances[owner()] = _reflectedSupply;

        // exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        // payday winnings will incur fees

        // exclude the owner and this contract from rewards
        _excludeFromRewards(owner());
        _excludeFromRewards(address(this));
        _excludeFromRewards(paydayAddress);

        emit Transfer(address(0), owner(), TOTAL_SUPPLY);
    }

    /** Functions required by IERC20Metadat **/
    function name() external pure override returns (string memory) {
        return NAME;
    }

    function symbol() external pure override returns (string memory) {
        return SYMBOL;
    }

    function decimals() external pure override returns (uint8) {
        return DECIMALS;
    }

    /** Functions required by IERC20Metadata - END **/
    /** Functions required by IERC20 **/
    function totalSupply() external pure override returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromRewards[account]) return _balances[account];
        return tokenFromReflection(_reflectedBalances[account]);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        address sender = _msgSender();
        _transfer(sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        address approver = _msgSender();
        _approve(approver, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    /** Functions required by IERC20 - END **/

    /**
     * @dev this is really a "soft" burn (total supply is not reduced). RFI holders
     * get two benefits from burning tokens:
     *
     * 1) Tokens in the burn address increase the % of tokens held by holders not
     *    excluded from rewards (assuming the burn address is excluded)
     * 2) Tokens in the burn address cannot be sold (which in turn draining the
     *    liquidity pool)
     *
     *
     * In RFI holders already get % of each transaction so the value of their tokens
     * increases (in a way). Therefore there is really no need to do a "hard" burn
     * (reduce the total supply). What matters (in RFI) is to make sure that a large
     * amount of tokens cannot be sold = draining the liquidity pool = lowering the
     * value of tokens holders own. For this purpose, transfering tokens to a (vanity)
     * burn address is the most appropriate way to "burn".
     *
     * There is an extra check placed into the `transfer` function to make sure the
     * burn address cannot withdraw the tokens is has (although the chance of someone
     * having/finding the private key is virtually zero).
     */
    function burn(uint256 amount) external {
        address sender = _msgSender();
        require(
            sender != address(0),
            "PaydayRfiToken: burn from the zero address"
        );
        require(
            sender != address(burnAddress),
            "PaydayRfiToken: burn from the burn address"
        );

        uint256 balance = balanceOf(sender);
        require(
            balance >= amount,
            "PaydayRfiToken: burn amount exceeds balance"
        );

        uint256 reflectedAmount = amount * _getCurrentRate();

        // remove the amount from the sender's balance first
        _reflectedBalances[sender] =
            _reflectedBalances[sender] -
            reflectedAmount;
        if (_isExcludedFromRewards[sender])
            _balances[sender] = _balances[sender] - amount;

        _burnTokens(sender, amount, reflectedAmount);
    }

    /**
     * @dev "Soft" burns the specified amount of tokens by sending them
     * to the burn address
     */
    function _burnTokens(
        address sender,
        uint256 tBurn,
        uint256 rBurn
    ) internal {
        /**
         * @dev Do not reduce _totalSupply and/or _reflectedSupply. (soft) burning by sending
         * tokens to the burn address (which should be excluded from rewards) is sufficient
         * in RFI
         */
        _reflectedBalances[burnAddress] =
            _reflectedBalances[burnAddress] +
            rBurn;
        if (_isExcludedFromRewards[burnAddress])
            _balances[burnAddress] = _balances[burnAddress] + tBurn;

        /**
         * @dev Emit the event so that the burn address balance is updated (on bscscan)
         */
        emit Transfer(sender, burnAddress, tBurn);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function isExcludedFromReward(address account)
        external
        view
        returns (bool)
    {
        return _isExcludedFromRewards[account];
    }

    /**
     * @dev Calculates and returns the reflected amount for the given amount with or without
     * the transfer fees (deductTransferFee true/false)
     */
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        external
        view
        returns (uint256)
    {
        require(tAmount <= TOTAL_SUPPLY, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , ) = _getValues(tAmount, 0);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , ) = _getValues(tAmount, sumOfFees);
            return rTransferAmount;
        }
    }

    /**
     * @dev Calculates and returns the amount of tokens corresponding to the given reflected amount.
     */
    function tokenFromReflection(uint256 rAmount)
        internal
        view
        returns (uint256)
    {
        require(
            rAmount <= _reflectedSupply,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getCurrentRate();
        return rAmount / currentRate;
    }

    function _excludeFromRewards(address account) internal {
        if (_reflectedBalances[account] > 0) {
            _balances[account] = tokenFromReflection(
                _reflectedBalances[account]
            );
        }
        _isExcludedFromRewards[account] = true;
        _excludedFromRewards.push(account);
    }

    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(
            owner != address(0),
            "PaydayRfiToken: approve from the zero address"
        );
        require(
            spender != address(0),
            "PaydayRfiToken: approve to the zero address"
        );

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     */
    function _isUnlimitedSender(address account) internal view returns (bool) {
        bool isUnlimited = false;
        // the owner should be the only whitelisted sender
        for (uint8 i = 0; i < sisterOAs.length; i++) {
            if (account == sisterOAs[i]) {
                isUnlimited = true;
            }
        }
        return (account == owner() || isUnlimited);
    }

    /**
     */
    function _isUnlimitedRecipient(address account)
        internal
        view
        returns (bool)
    {
        // the owner should be a white-listed recipient
        // and anyone should be able to burn as many tokens as
        // he/she wants
        bool isUnlimited = false;
        for (uint8 i = 0; i < sisterOAs.length; i++) {
            if (account == sisterOAs[i]) {
                isUnlimited = true;
            }
        }
        return (account == owner() || account == burnAddress || isUnlimited);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(
            sender != address(0),
            "PaydayRfiToken: transfer from the zero address"
        );
        require(
            recipient != address(0),
            "PaydayRfiToken: transfer to the zero address"
        );
        require(
            sender != address(burnAddress),
            "PaydayRfiToken: transfer from the burn address"
        );
        require(amount > 0, "Transfer amount must be greater than zero");

        // indicates whether or not feee should be deducted from the transfer
        bool takeFee = true;

        /**
         * Check the amount is within the max allowed limit as long as a
         * unlimited sender/recepient is not involved in the transaction
         */
        if (
            amount > maxTransactionAmount &&
            !_isUnlimitedSender(sender) &&
            !_isUnlimitedRecipient(recipient)
        ) {
            revert("Transfer amount exceeds the maxTxAmount.");
        }
        /**
         * The pair needs to excluded from the max wallet balance check;
         * selling tokens is sending them back to the pair (without this
         * check, selling tokens would not work if the pair's balance
         * was over the allowed max)
         *
         * Note: This does NOT take into account the fees which will be deducted
         *       from the amount. As such it could be a bit confusing
         */
        if (
            maxWalletBalance > 0 &&
            !_isUnlimitedSender(sender) &&
            !_isUnlimitedRecipient(recipient) &&
            !_isV2Pair(recipient)
        ) {
            uint256 recipientBalance = balanceOf(recipient);
            require(
                recipientBalance + amount <= maxWalletBalance,
                "New balance would exceed the maxWalletBalance"
            );
        }

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            takeFee = false;
        }

        _beforeTokenTransfer(sender, recipient, amount, takeFee);

        // if (_isV2Pair(sender) && !_isV2Pair(recipient)) {
        //     // Buy transaction
        // } else if (!_isV2Pair(sender) && _isV2Pair(recipient)) {
        //     // Sell transaction
        // } else if (_isV2Pair(sender) && _isV2Pair(recipient)) {
        //    // hop between LPs - avoiding double tax
        //    takeFee = false;
        //}

        _transferTokens(sender, recipient, amount, takeFee);
    }

    function _transferTokens(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        /**
         * The `_takeFees` call takes care of the individual fees
         */
        uint256 feesTotal = sumOfFees;
        if (!takeFee) {
            feesTotal = 0;
        }

        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tAmount,
            uint256 tTransferAmount,
            uint256 currentRate
        ) = _getValues(amount, feesTotal);

        /**
         * Sender's and Recipient's reflected balances must be always updated regardless of
         * whether they are excluded from rewards or not.
         */
        _reflectedBalances[sender] = _reflectedBalances[sender] - rAmount;
        _reflectedBalances[recipient] =
            _reflectedBalances[recipient] +
            rTransferAmount;

        /**
         * Update the true/nominal balances for excluded accounts
         */
        if (_isExcludedFromRewards[sender]) {
            _balances[sender] = _balances[sender] - tAmount;
        }
        if (_isExcludedFromRewards[recipient]) {
            _balances[recipient] = _balances[recipient] + tTransferAmount;
        }

        _takeFees(amount, currentRate, feesTotal);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeFees(
        uint256 amount,
        uint256 currentRate,
        uint256 sumOfFees
    ) private {
        if (sumOfFees > 0) {
            _takeTransactionFees(amount, currentRate);
        }
    }

    function _getValues(uint256 tAmount, uint256 feesSum)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tTotalFees = 0;
        if (feesSum > 0) {
            tTotalFees = (tAmount * feesSum) / FEES_DIVISOR;
        }
        uint256 tTransferAmount = tAmount - tTotalFees;
        uint256 currentRate = _getCurrentRate();
        uint256 rAmount = tAmount * currentRate;
        uint256 rTotalFees = tTotalFees * currentRate;
        uint256 rTransferAmount = rAmount - rTotalFees;

        return (
            rAmount,
            rTransferAmount,
            tAmount,
            tTransferAmount,
            currentRate
        );
    }

    function _getCurrentRate() internal view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() internal view returns (uint256, uint256) {
        uint256 rSupply = _reflectedSupply;
        uint256 tSupply = TOTAL_SUPPLY;

        /**
         * The code below removes balances of addresses excluded from rewards from
         * rSupply and tSupply, which effectively increases the % of transaction fees
         * delivered to non-excluded holders
         */
        for (uint256 i = 0; i < _excludedFromRewards.length; i++) {
            if (
                _reflectedBalances[_excludedFromRewards[i]] > rSupply ||
                _balances[_excludedFromRewards[i]] > tSupply
            ) return (_reflectedSupply, TOTAL_SUPPLY);
            rSupply = rSupply - _reflectedBalances[_excludedFromRewards[i]];
            tSupply = tSupply - _balances[_excludedFromRewards[i]];
        }
        if (tSupply == 0 || rSupply < _reflectedSupply / TOTAL_SUPPLY)
            return (_reflectedSupply, TOTAL_SUPPLY);
        return (rSupply, tSupply);
    }

    /**
     * @dev Hook that is called before any transfer of tokens.
     */
    function _beforeTokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) internal virtual;

    /**
     * @dev Redistributes the specified amount among the current holders via the reflect.finance
     * algorithm, i.e. by updating the _reflectedSupply (_rSupply) which ultimately adjusts the
     * current rate used by `tokenFromReflection` and, in turn, the value returns from `balanceOf`.
     * This is the bit of clever math which allows rfi to redistribute the fee without
     * having to iterate through all holders.
     *
     * Visit our discord at https://discord.gg/dAmr6eUTpM
     */
    function _redistribute(
        uint256 amount,
        uint256 currentRate,
        uint256 fee,
        uint256 index
    ) internal {
        uint256 tFee = (amount * fee) / FEES_DIVISOR;
        uint256 rFee = tFee * currentRate;

        _reflectedSupply = _reflectedSupply - rFee;
        _addFeeCollectedAmount(index, tFee);
    }

    /**
     * @dev Hook that is called before the `Transfer` event is emitted if fees are enabled for the transfer
     */
    function _takeTransactionFees(uint256 amount, uint256 currentRate)
        internal
        virtual;

    /**
     * @dev Airdrop function only accessible to Owner to deliver BSKR to sacrificers
     * This control will cease once ownership is renounced
     */
    function airdrop(address account, uint256 amount)
        external
        override
        onlyOwner
    {
        require(
            account != address(0),
            "PaydayRfiToken: transfer to the zero address"
        );
        require(
            account != address(burnAddress),
            "PaydayRfiToken: transfer to the burn address"
        );
        require(amount > 0, "Transfer amount must be greater than zero");

        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tAmount,
            uint256 tTransferAmount,
            // uint256 currentRate
        ) = _getValues(amount, 0); // no fees

        /**
         * Sender's and Recipient's reflected balances must be always updated regardless of
         * whether they are excluded from rewards or not.
         */
        _reflectedBalances[owner()] = _reflectedBalances[owner()] - rAmount;
        _reflectedBalances[account] =
            _reflectedBalances[account] +
            rTransferAmount;

        /**
         * Update the true/nominal balances for excluded accounts
         */
        // Owner is excluded from rewards
        _balances[owner()] = _balances[owner()] - tAmount;
        if (_isExcludedFromRewards[account]) {
            _balances[account] = _balances[account] + tTransferAmount;
        }
    }

    function getOriginAddress() internal override returns (address) {
        if (oaIndex < (sisterOAs.length - 1)) {
            oaIndex = oaIndex + 1;
        } else {
            oaIndex = 0;
        }
        return sisterOAs[oaIndex];
    }
}
