//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./Preload.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title A contract for KEKSGO_DEX.
 * NOTE: The contract of DEX with a decentralized orderbook and a custom ERC-20 token.
 */
contract KEKSGO_DEX is _MSG, IKEK_DEX {
    struct Order {
        uint256 id;
        address user;
        address tokenGet;
        uint256 amountGet;
        address tokenGive;
        uint256 amountGive;
        uint256 timestamp;
    }

    address public constant ETHER = address(0); //allows as to store Ether in tokens mapping with blank address
    address private _feeToSetter; // the acccount that sets the exchange fees receiver & percentage
    address payable private _feeAccount; // the acccount that receives exchange fees 
    mapping(address => uint256) private _feePercent; // the fee percentage

    uint256 private _orderCount;
    uint256 private bp; // basis points enables lower fees with wider range in calculation

    // Mapping from token address to mapping from user address to amount of tokens.
    mapping(address => mapping(address => uint256)) private _tokens;
    mapping(address => mapping(address => uint256)) private _tokensOnHold;
    mapping(address => mapping(uint256 => uint256)) private _feeOnHold;
    mapping(address => uint256) public _tokenOnHold;
    // Mapping from order Id to Order object.
    mapping(uint256 => Order) public _orders;
    // Mapping from order Id to bool ( whether the order was canceled ).
    mapping(uint256 => bool) private _orderCancelled;
    // Mapping from order Id to bool ( whether the order was filled ).
    mapping(uint256 => bool) private _orderFilled;

    /**
     * @dev Emitted when the user deposits the tokens to the exchange.
     * @param token address of the deposited token.
     * @param user address of the user that deposited tokens.
     * @param amount amount of deposited tokens.
     * @param balance the exchange balance of these user tokens after deposit.
     */
    event Deposit(address token, address user, uint256 amount, uint256 balance);
    /**
     * @dev Emitted when the user withdraws the tokens from the exchange.
     * @param token the address of the token to be withdrawn.
     * @param user address of the user to whom funds are withdrawn.
     * @param amount amount of withdrawn tokens.
     * @param balance the exchange balance of these user tokens after withdrawn.
     */
    event Withdraw(address token, address user, uint256 amount, uint256 balance);
    /**
     * @dev Emitted when the user create an order.
     * @param id order count id.
     * @param user address of the user that create this order.
     * @param tokenGet the address of the token that the user wants to get.
     * @param amountGet the amount of `tokenGet` token user wants to get.
     * @param tokenGive the address of the token that the user wants to give.
     * @param amountGive the amount of `tokenGive` token user wants to give.
     * @param timestamp time of order creation.
     */
    event OrderCreated(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
    /**
     * @dev Emitted when the user cancel an order.
     * @param id id of the cancelled order.
     * @param user address of the user that cancelled this order.
     * @param tokenGet the address of the token that the user wanted to get previously.
     * @param amountGet the amount of `tokenGet` token user wanted to get previously.
     * @param tokenGive the address of the token that the user wanted to give previously.
     * @param amountGive the amount of `tokenGive` token user wanted to give previously.
     * @param timestamp time of order cancelling.
     */
    event OrderCancelled(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        uint256 timestamp
    );
    /**
     * @dev Emitted when the trade happened.
     * @param id id of the filled order.
     * @param user address of the user that create this order.
     * @param tokenGet the address of the token that user received.
     * @param amountGet the amount of `tokenGet` token user received.
     * @param tokenGive the address of the token that the user gived.
     * @param amountGive the amount of `tokenGive` token user gived.
     * @param userFill address of the user that maked this deal with `user`.
     * @param timestamp time of the transaction.
     */
    event OrderFilled(
        uint256 id,
        address user,
        address tokenGet,
        uint256 amountGet,
        address tokenGive,
        uint256 amountGive,
        address userFill,
        uint256 timestamp
    );

    /**
     * @dev Sets up the `_feeAccount` and `_feePercent`.
     * @param feeAccount_ the address to which all fees will be transferred.
     */
    constructor(address feeAccount_) {
        require(feeAccount_ != address(0), "Fee account cannot be address zero");
        _feeAccount = payable(feeAccount_);
        _feePercent[ETHER] = 5000000000000000;
    }

    /// @dev Fallback: reverts if Ether is sent to this smart contract by mistake
    fallback() external payable {
        depositEther();
    }

    receive() external payable {
        depositEther();
    }

    function setFeeToSetter(address payable feeToSetter) public virtual {
        _feeToSetter = feeToSetter;
    }

    function setFeeTo(address payable feeTo) public virtual {
        require(address(_msgSender()) == _feeToSetter);
        _feeAccount = feeTo;
    }
    
    function setFee(uint256 fee) public virtual {
        require(address(_msgSender()) == _feeToSetter);
        require(uint256(fee) <= uint256(1000),"fee must be less than 10%");
        require(uint256(fee) >= uint256(10),"fee must be greater than 0.1%");
        _feePercent[ETHER] = fee;
    }
    
    function setTokenFee(address token, uint256 fee) public virtual {
        require(address(_msgSender()) == _feeToSetter);
        require(uint256(fee) <= uint256(1000),"fee must be less than 10%");
        require(uint256(fee) >= uint256(10),"fee must be greater than 0.1%");
        _feePercent[token] = fee;
    }
    
    function withdrawFees(address token) public virtual returns(bool) {
        require(IERC20(token).transfer(_feeAccount, _tokens[token][_feeAccount]));
        _tokens[token][_feeAccount] -= _tokens[token][_feeAccount];
        return true;
    }
    
    function returnTokenFees(address token) public virtual returns(uint) {
        return _tokens[token][_feeAccount];
    }
    
    function returnNativeFees() public virtual returns(uint) {
        return _tokens[ETHER][_feeAccount];
    }
    
    function withdrawNativeFees() public virtual returns(bool) {
        (bool success,) = payable(_feeAccount).call{value: _tokens[ETHER][_feeAccount]}("");
        require(success == true);
        _tokens[ETHER][_feeAccount] -= _tokens[ETHER][_feeAccount];
        return success;
    }
    /**
     * @dev The function allows users to deposit Ether to exchange.
     *
     * Requirements:
     *
     * - `msg.value` cannot be zero.
     *
     * Emits a {Deposit} event.
     */
    function depositEther() public payable {
        require(msg.value != 0, "Value cannot be zero");
        _tokens[ETHER][_msgSender()] = _tokens[ETHER][_msgSender()] + (msg.value);
        emit Deposit(ETHER, _msgSender(), msg.value, _tokens[ETHER][_msgSender()]);
    }

    /**
     * @dev The function allows users to withdraw Ether from exchange.
     *
     * Requirements:
     *
     * - `amount_` cannot be zero.
     * - user must have enough `amount_` of `ETHER` in `_tokens` mapping.
     *
     * @param amount_ the amount of ETH to be withdrawn.
     *
     * Emits a {Withdraw} event.
     */
    function withdrawEther(uint256 amount_) public {
        require(amount_ != 0, "Value cannot be zero");
        require(_tokens[ETHER][_msgSender()] >= amount_);
        _tokens[ETHER][_msgSender()] = _tokens[ETHER][_msgSender()] - (amount_);
        payable(_msgSender()).transfer(amount_);
        emit Withdraw(ETHER, _msgSender(), amount_, _tokens[ETHER][_msgSender()]);
    }

    /**
     * @dev The function allows users to deposit erc-20 tokens to exchange.
     *
     * Requirements:
     *
     * - `token_` address cannot be `ETHER` ( or address(0) ) address.
     * - `_msgSender()` required to approve amount of `token_` to be deposited to this contract.
     *
     * @param token_ address of the token to be deposited.
     * @param amount_ the amount of `token_` to be deposited.
     *
     * Emits a {Deposit} event.
     */
    function depositToken(address token_, uint256 amount_) public {
        //Don't allow ETHER deposits
        require(token_ != ETHER, "ERC20 cannot be address zero");
        // Send tokens to this contract
        IERC20(token_).transferFrom(_msgSender(), address(this), amount_);
        // Manage deposit - update balance
        _tokens[token_][_msgSender()] = _tokens[token_][_msgSender()] + (amount_);
        // Emit event
        emit Deposit(token_, _msgSender(), amount_, _tokens[token_][_msgSender()]);
    }

    /**
     * @dev The function allows users to withdraw erc-20 tokens from exchange.
     *
     * Requirements:
     *
     * - `token_` address cannot be `ETHER` ( or address(0) ) address.
     * - user must have enough `amount_` of `token_` in `_tokens` mapping.
     *
     * @param token_ erc-20 token address for withdrawal.
     * @param amount_ the amount of `token_` to be withdrawn.
     *
     * Emits a {Withdraw} event.
     */
    function withdrawToken(address token_, uint256 amount_) public {
        require(token_ != ETHER, "ERC20 cannot be address zero");
        require(_tokens[token_][_msgSender()] >= amount_);
        // toDo fix the amount on hold to ensure withdrawls cancel order first!!
        // require(uint(amount_) < uint(_tokensOnHold[tokenGive_][_msgSender()]),"Cancel orders first!")
        _tokens[token_][_msgSender()] = _tokens[token_][_msgSender()] - (amount_);
        IERC20(token_).transfer(_msgSender(), amount_);
        emit Withdraw(token_, _msgSender(), amount_, _tokens[token_][_msgSender()]);
    }

    /**
     * @dev Returns the balance of an individual token of an individual user.
     * @param token_ address of token or Ether internal address to be explored.
     * @param user_ user's address to check the amount of `token_` they has on the exchange.
     */
    function balanceOf(address token_, address user_) public view returns (uint256) {
        return _tokens[token_][user_];
    }

    /**
     * @dev The function allows users to create and add orders to orderbook.
     *
     * Requirements:
     *
     * - `amountGet_` cannot be zero.
     * - `amountGive_` cannot be zero.
     *
     * @param tokenGet_ the address of the token that the user wants to get.
     * @param amountGet_ the amount of `tokenGet` token user wants to get.
     * @param tokenGive_ the address of the token that the user wants to give.
     * @param amountGive_ the amount of `tokenGive` token user wants to give.
     *
     * Emits a {OrderCreated} event.
     */
    function makeOrder(
        address tokenGet_,
        uint256 amountGet_,
        address tokenGive_,
        uint256 amountGive_
    ) public payable override {
        require(amountGet_ != 0, "Getting amount cannot be zero");
        require(amountGive_ != 0, "Giving amount cannot be zero");
        require(_tokens[tokenGive_][_msgSender()] >= amountGive_, "Must deposit token to make orders in token!");
        // maker fee in ether
        uint256 _feeAmount = _feePercent[ETHER];
        require(msg.value >= uint(_feeAmount),"Not enough fee");
        // place tokens on hold || BLOCK WITHDRAWAL
        _tokensOnHold[tokenGive_][_msgSender()] += amountGive_;
        _tokenOnHold[tokenGive_]+=amountGive_;
        // take fee
        amountGive_-=_feeAmount;
        _tokens[ETHER][_feeAccount] += _feeAmount;
        // take tokens
        _tokens[tokenGive_][_msgSender()] -= amountGive_;
        // hold tokens
        _tokens[tokenGive_][address(this)] += amountGive_;
        _orderCount = _orderCount + 1;
        _feeOnHold[tokenGive_][_orderCount]+=_feeAmount;
        _orders[_orderCount] = Order(
            _orderCount,
            _msgSender(),
            tokenGet_,
            amountGet_,
            tokenGive_,
            amountGive_,
            block.timestamp
        );
        emit OrderCreated(_orderCount, _msgSender(), tokenGet_, amountGet_, tokenGive_, amountGive_, block.timestamp);
    }

    function makeOrderFeeInToken(
        address tokenGet_,
        uint256 amountGet_,
        address tokenGive_,
        uint256 amountGive_
    ) public override {
        require(amountGet_ != 0, "Getting amount cannot be zero");
        require(amountGive_ != 0, "Giving amount cannot be zero");
        require(_tokens[tokenGive_][_msgSender()] >= amountGive_, "Must deposit token to make orders in token!");
        // maker fee in token
        uint256 _feeAmount = (amountGive_ * _feePercent[tokenGive_]) / (bp);
        require(uint(IERC20(tokenGive_).balanceOf(_msgSender())) >= uint(_feeAmount),"Not enough fee");
        _tokensOnHold[tokenGive_][_msgSender()] += amountGive_;
        _tokenOnHold[tokenGive_]+=amountGive_;
        // take fee
        amountGive_-=_feeAmount;
        _tokens[tokenGive_][_feeAccount] += _feeAmount;
        // take tokens
        _tokens[tokenGive_][_msgSender()] -= amountGive_;
        // hold tokens
        _tokens[tokenGive_][address(this)] += amountGive_;
        _orderCount = _orderCount + 1;
        _feeOnHold[tokenGive_][_orderCount]+=_feeAmount;
        _orders[_orderCount] = Order(
            _orderCount,
            _msgSender(),
            tokenGet_,
            amountGet_,
            tokenGive_,
            amountGive_,
            block.timestamp
        );
        emit OrderCreated(_orderCount, _msgSender(), tokenGet_, amountGet_, tokenGive_, amountGive_, block.timestamp);
    }

    /**
     * @dev The function allows users to cancel and remove their own orders from orderbook.
     *
     * Requirements:
     *
     * - `_msgSender()` must be the creator of `id_` order.
     * - the order must exist.
     *
     * @param id_ id of the order to be removed from orderbook.
     *
     * Emits a {OrderCancelled} event.
     */
    function cancelOrder(uint256 id_) public {
        Order storage order = _orders[id_];
        require(address(order.user) == _msgSender());
        require(order.id == id_);
        _orderCancelled[id_] = true;
        emit OrderCancelled(
            order.id,
            _msgSender(),
            order.tokenGet,
            order.amountGet,
            order.tokenGive,
            order.amountGive,
            block.timestamp
        );
    }

    /**
     * @dev The function allows users to filled orders and make trades.
     *
     * Requirements:
     *
     * - the order must exist and `id_` of order cannot be higher than `_orderCount`.
     * - order cannot be filled already.
     * - order cannot be cancelled already.
     *
     * @param id_ id of the order to be filled.
     *
     * Emits a {OrderFilled} event.
     */
    function fillOrder(uint256 id_) public {
        require(id_ > 0 && id_ <= _orderCount, "The order must exist");
        require(!_orderFilled[id_], "The order cannot be filled already");
        require(!_orderCancelled[id_], "The order cannot be cancelled already");
        Order storage order = _orders[id_];
        _trade(order.id, order.user, order.tokenGet, order.amountGet, order.tokenGive, order.amountGive);
        _orderFilled[order.id] = true;
    }

    /**
     * @dev The trade function with charging fees from users.
     *
     * Requirements:
     *
     * - Fee paid by the user that fills the order, so `_msgSender()` must have enough tokens to cover exchange fees.
     *
     * @param id_ id of the order to be filled.
     * @param user_ the address of the creator of the order.
     * @param tokenGet_ the address of the token that the `user_` wants to get and `_msgSender()` wants to give.
     * @param amountGet_ the amount of `tokenGet` token `user_` wants to get and `_msgSender()` wants to give.
     * @param tokenGive_ the address of the token that the `user_` wants to give and `_msgSender()` wants to get.
     * @param amountGive_ the amount of `tokenGive` token `user_` wants to give and `_msgSender()` wants to get.
     *
     * Emits a {OrderFilled} event.
     */
    function _trade(
        uint256 id_,
        address user_,
        address tokenGet_,
        uint256 amountGet_,
        address tokenGive_,
        uint256 amountGive_
    ) internal {
        _tokenOnHold[tokenGive_]-=amountGive_;
        // _feeOnHold[tokenGive_]+=_feeAmount;
        _tokensOnHold[tokenGive_][user_] -= amountGive_;
        _tokens[tokenGive_][address(this)] -= amountGive_;
        _tokens[tokenGet_][_msgSender()] -= amountGet_;
        _tokens[tokenGive_][_msgSender()] += amountGive_;
        _tokens[tokenGet_][user_] += amountGet_;
        emit OrderFilled(id_, user_, tokenGet_, amountGet_, tokenGive_, amountGive_, _msgSender(), block.timestamp);
    }
}
