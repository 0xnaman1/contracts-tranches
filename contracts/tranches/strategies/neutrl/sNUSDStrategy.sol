// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IErrors} from "../../interfaces/IErrors.sol";
import {IStrataCDO} from "../../interfaces/IStrataCDO.sol";
import {IERC20Cooldown, IUnstakeCooldown} from "../../interfaces/cooldown/ICooldown.sol";
import {Strategy} from "../../Strategy.sol";

contract sNUSDStrategy is Strategy {
    IERC4626 public immutable sNUSD;
    IERC20 public immutable NUSD;

    IERC20Cooldown public erc20Cooldown;
    IUnstakeCooldown public unstakeCooldown;

    uint256 public sNUSDCooldownJrt;
    uint256 public sNUSDCooldownSrt;

    event CooldownsChanged(uint256 jrt, uint256 srt);

    constructor(IERC4626 sNUSD_) {
        sNUSD = sNUSD_;
        NUSD = IERC20(sNUSD_.asset());
    }

    function initialize(
        address owner_,
        address acm_,
        IStrataCDO cdo_,
        IERC20Cooldown erc20Cooldown_,
        IUnstakeCooldown unstakeCooldown_
    ) public virtual initializer {
        AccessControlled_init(owner_, acm_);

        cdo = cdo_;
        erc20Cooldown = erc20Cooldown_;
        unstakeCooldown = unstakeCooldown_;

        SafeERC20.forceApprove(sNUSD, address(erc20Cooldown), type(uint256).max);
        SafeERC20.forceApprove(sNUSD, address(unstakeCooldown), type(uint256).max);
    }

    function deposit(address, address token, uint256 tokenAmount, uint256 baseAssets, address owner)
        external
        onlyCDO
        returns (uint256)
    {
        SafeERC20.safeTransferFrom(IERC20(token), owner, address(this), tokenAmount);

        if (token == address(NUSD)) {
            SafeERC20.forceApprove(NUSD, address(sNUSD), tokenAmount);
            sNUSD.deposit(tokenAmount, address(this));
            return tokenAmount;
        }
        if (token == address(sNUSD)) {
            return baseAssets;
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
    ) external onlyCDO returns (uint256) {
        uint256 shares = sNUSD.previewWithdraw(baseAssets);
        if (token == address(sNUSD)) {
            uint256 cooldownSeconds = cdo.isJrt(tranche) ? sNUSDCooldownJrt : sNUSDCooldownSrt;
            erc20Cooldown.transfer(sNUSD, sender, receiver, shares, cooldownSeconds);
            return shares;
        }
        if (token == address(NUSD)) {
            unstakeCooldown.transfer(sNUSD, sender, receiver, shares);
            return baseAssets;
        }
        revert UnsupportedToken(token);
    }

    function reduceReserve(address token, uint256 tokenAmount, address receiver) external onlyCDO {
        if (token == address(sNUSD)) {
            erc20Cooldown.transfer(sNUSD, receiver, receiver, tokenAmount, 0);
            return;
        }
        if (token == address(NUSD)) {
            uint256 shares = sNUSD.convertToShares(tokenAmount);
            if (shares == 0) {
                revert ZeroAmount();
            }
            unstakeCooldown.transfer(sNUSD, receiver, receiver, shares);
            return;
        }
        revert UnsupportedToken(token);
    }

    function convertToAssets(address token, uint256 tokenAmount, Math.Rounding rounding)
        external
        view
        returns (uint256)
    {
        if (token == address(sNUSD)) {
            return rounding == Math.Rounding.Floor ? sNUSD.previewRedeem(tokenAmount) : sNUSD.previewMint(tokenAmount);
        }
        if (token == address(NUSD)) {
            return tokenAmount;
        }
        revert UnsupportedToken(token);
    }

    function convertToTokens(address token, uint256 baseAssets, Math.Rounding rounding)
        external
        view
        returns (uint256)
    {
        if (token == address(sNUSD)) {
            return rounding == Math.Rounding.Floor
                ? sNUSD.previewDeposit(baseAssets)
                : sNUSD.previewWithdraw(baseAssets);
        }
        if (token == address(NUSD)) {
            return baseAssets;
        }
        revert UnsupportedToken(token);
    }

    function getSupportedTokens() external view returns (IERC20[] memory) {
        IERC20[] memory tokens = new IERC20[](2);
        tokens[0] = IERC20(address(sNUSD));
        tokens[1] = NUSD;
        return tokens;
    }

    function totalAssets() external view returns (uint256 baseAssets) {
        uint256 shares = sNUSD.balanceOf(address(this));
        baseAssets = sNUSD.previewRedeem(shares);
        return baseAssets;
    }

    function setCooldowns(uint256 sNUSDCooldownJrt_, uint256 sNUSDCooldownSrt_)
        external
        onlyRole(UPDATER_STRAT_CONFIG_ROLE)
    {
        uint256 WEEK = 7 days;
        if (sNUSDCooldownJrt_ > WEEK || sNUSDCooldownSrt_ > WEEK) {
            revert InvalidConfigCooldown();
        }
        sNUSDCooldownJrt = sNUSDCooldownJrt_;
        sNUSDCooldownSrt = sNUSDCooldownSrt_;

        bool isDisabled = sNUSDCooldownJrt_ == 0 && sNUSDCooldownSrt_ == 0;
        erc20Cooldown.setCooldownDisabled(sNUSD, isDisabled);
        emit CooldownsChanged(sNUSDCooldownJrt_, sNUSDCooldownSrt_);
    }
}

