//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract _MSG {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title GO_KEKCHAIN contract
 * NOTE: Contract inherit from openzeppelin ERC20
 */
contract GO_KEKCHAIN is ERC20 {
    /**
     * @dev Each token has 18 decimals
     * Mint initial 75000 amount of tokens for the owner
     */
    constructor() ERC20("GO-KEKCHAIN", "gKEK") {
        _mint(_msgSender(), 100000 * 10**18);
    }
}
