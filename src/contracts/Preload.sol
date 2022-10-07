//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

abstract contract _MSG {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IKEK_DEX {
    function depositEther() external payable;
    function withdrawEther(uint256 amount_) external;
    function depositToken(address token_, uint256 amount_) external;
    function withdrawToken(address token_, uint256 amount_) external;
    function balanceOf(address token_, address user_) external view returns (uint256);
    function makeOrder(address tokenGet_,uint256 amountGet_,address tokenGive_,uint256 amountGive) external;
    function cancelOrder(uint256 id_) external;
    function fillOrder(uint256 id_) external;
    
}
