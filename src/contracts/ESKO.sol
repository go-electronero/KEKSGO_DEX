//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

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
        _mint(msg.sender, 100000 * 10**18);
    }
}
