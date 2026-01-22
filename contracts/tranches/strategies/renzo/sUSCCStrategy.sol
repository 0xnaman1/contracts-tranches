// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IErrors} from "../../interfaces/IErrors.sol";
import {IStrataCDO} from "../../interfaces/IStrataCDO.sol";
import {IUnstakeCooldown} from "../../interfaces/cooldown/ICooldown.sol";
import {Strategy} from "../../Strategy.sol";

contract sUSCCStrategy is Strategy {
    IERC4626 public immutable ezUSCC1;
    IERC20 public immutable USDC;

    // IERC20Cooldown public erc20Cooldown;
    IUnstakeCooldown public unstakeCooldown;

    uint256 public sUSCCCooldownJrt;
    uint256 public sUSCCCooldownSrt;

    constructor(IERC4626 ezUSCC1_, IERC20 USDC_) {
        ezUSCC1 = ezUSCC1_;
        USDC = USDC_;
    }

    function initialize(address owner_, address acm_, IStrataCDO cdo_, IUnstakeCooldown unstakeCooldown_)
        public
        virtual
        initializer
    {
        AccessControlled_init(owner_, acm_);

        cdo = cdo_;
        unstakeCooldown = unstakeCooldown_;

        SafeERC20.forceApprove(ezUSCC1, address(unstakeCooldown), type(uint256).max);
    }

    function deposit(address, address token, uint256 tokenAmount, uint256 baseAssets, address owner)
        external
        returns (uint256)
    {
        SafeERC20.safeTransferFrom(IERC20(token), owner, address(this), tokenAmount);

        if (token == address(USDC)) {
            SafeERC20.forceApprove(USDC, address(ezUSCC1), tokenAmount);
            ezUSCC1.deposit(tokenAmount, address(this));
            return tokenAmount;
        }
        revert UnsupportedToken(token);
    }

    function withdraw(
        address tranche,
        address token,
        uint256 tokenAmount,
        uint256 baseAssets,
        address sender,
        address receiver
    ) external returns (uint256) {
        return withdrawInner(tranche, token, tokenAmount, baseAssets, sender, receiver, false);
    }

    function withdraw(
        address tranche,
        address token,
        uint256 tokenAmount,
        uint256 baseAssets,
        address sender,
        address receiver,
        bool shouldSkipCooldown
    ) external returns (uint256) {
        return withdrawInner(tranche, token, tokenAmount, baseAssets, sender, receiver, shouldSkipCooldown);
    }

    function withdrawInner(
        address tranche,
        address token,
        uint256 tokenAmount,
        uint256 baseAssets,
        address sender,
        address receiver,
        bool shouldSkipCooldown
    ) internal returns (uint256) {}

    function totalAssets() external view returns (uint256) {}
    function reduceReserve(address token, uint256 tokenAmount, address receiver) external {}

    function convertToAssets(address token, uint256 tokenAmount, Math.Rounding rounding)
        external
        view
        returns (uint256 baseAssets)
    {}
    function convertToTokens(address token, uint256 baseAssets, Math.Rounding rounding)
        external
        view
        returns (uint256 tokenAmount)
    {}

    function getSupportedTokens() external view returns (IERC20[] memory) {}
}
