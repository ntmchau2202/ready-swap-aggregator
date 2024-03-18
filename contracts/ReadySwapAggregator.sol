// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

pragma experimental ABIEncoderV2;


import "./libraries/SafeERC20.sol";
import "./libraries/Math.sol";

import "./helpers/Ownable.sol";

import "./helpers/Pausable.sol";

import "./libraries/UniversalERC20.sol";

import "./helpers/ReentrancyGuard.sol";

import "./helpers/Whitelist.sol";

/**
 * @title ReadySwapAggregator
 * @dev perform calls to dex aggregators whitelisted
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract ReadySwapAggregator is Ownable, ReentrancyGuard, Pausable, Whitelist {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using UniversalERC20 for IERC20;

    constructor(
        address _owner
    )  {
        transferOwnership(_owner);
    }

    // NOTES: steps:
    // 1. make a call from user wallet to the dex contract, transfer back token to this contract
    // the call must have bytecode that specifies the origin of the call, the dex address to be called and the destination wallet to receive tokens after swap

    function swap(
        IERC20 baseToken,
        address targetDex,
        bytes memory data,
        IERC20 quoteToken,
        uint256 outAmount,
        uint256 feeRate
        // if target Dex is not whitelisted, raise error immediately
        // should use feeRate instead of fee since the actual balance may not meet the desired output
        // hence, the subtraction only may cause returns to user negative                                                                               
    ) public payable {
        require(
            (msg.value != 0) == baseToken.isETH(),
            "msg.value should be used only for ETH swap"
        );

        require(this.isMember(targetDex), "DEX is not supported");
        // save old value for validation later
        uint256 oldBalance = quoteToken.universalBalanceOf(address(this));
        (bool ok,) = payable(targetDex).call{value: msg.value} (
            data
        );
        require(ok, "Swap failed");
        // calculate amount of token to be transfered to user

        uint256 newBalance = quoteToken.universalBalanceOf(address(this));
        uint256 received = newBalance.sub(oldBalance);
        uint256 actualSwapped = Math.min(
            outAmount,
            received 
        );
        uint256 fee = actualSwapped.mul(feeRate).div(10000);
        uint256 remaining = actualSwapped.sub(fee);
        quoteToken.transferFrom(address(this), msg.sender, remaining);
    }

}