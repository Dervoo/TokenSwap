// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract TokenSwap {

    /// @dev Two different token addresses

    IERC20 public immutable tokenOne;
    IERC20 public immutable tokenTwo;

    /// @dev deployed token's balances sent to Swapper contract

    uint public reserveOne;
    uint public reserveTwo;

    uint public totalSupply;
    /// @dev keeping balance inside of mapping
    mapping(address => uint) public balanceOf;

    /// @dev For use we gotta pass two deployed tokens here
    constructor(address _tokenOne, address _tokenTwo) {
        tokenOne = IERC20(_tokenOne);
        tokenTwo = IERC20(_tokenTwo);
    }

    function _mint(address _to, uint _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    function _burn(address _from, uint _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    function _update(uint _reserveOne, uint _reserveTwo) private {
        reserveOne = _reserveOne;
        reserveTwo = _reserveTwo;
    }

    /// @dev swaps tokens with Fees

    function swap(address _tokenIn, uint _amountIn) external returns (uint amountOut) {
        require(
            _tokenIn == address(tokenOne) || _tokenIn == address(tokenTwo),
            "invalid token"
        );
        require(_amountIn > 0, "amount in = 0");

        bool istokenOne = _tokenIn == address(tokenOne);
        (IERC20 tokenIn, IERC20 tokenOut, uint reserveIn, uint reserveOut) = istokenOne
            ? (tokenOne, tokenTwo, reserveOne, reserveTwo)
            : (tokenTwo, tokenOne, reserveTwo, reserveOne);

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        uint amountInWithFee = (_amountIn * 997) / 1000;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        tokenOut.transfer(msg.sender, amountOut);

        _update(tokenOne.balanceOf(address(this)), tokenTwo.balanceOf(address(this)));
    }

    /// @dev this function needs approval for certain amount of tokens to add tokens to Swapper (to the caller of the function)

    function addLiquidity(uint _amount0, uint _amount1) external returns (uint shares) {
        tokenOne.transferFrom(msg.sender, address(this), _amount0);
        tokenTwo.transferFrom(msg.sender, address(this), _amount1);
        // tokenOne.transferFrom(tokenOne, address(this), _amount0);
        // tokenTwo.transferFrom(tokenTwo, address(this), _amount1);

        if (reserveOne > 0 || reserveTwo > 0) {
            require(reserveOne * _amount1 == reserveTwo * _amount0, "x / y != dx / dy");
        }

        if (totalSupply == 0) {
            shares = _sqrt(_amount0 * _amount1);
        } else {
            shares = _min(
                (_amount0 * totalSupply) / reserveOne,
                (_amount1 * totalSupply) / reserveTwo
            );
        }
        require(shares > 0, "shares = 0");
        _mint(msg.sender, shares);

        _update(tokenOne.balanceOf(address(this)), tokenTwo.balanceOf(address(this)));
    }

    function removeLiquidity(uint _shares)
        external
        returns (uint amount0, uint amount1)
    {
        uint bal0 = tokenOne.balanceOf(address(this));
        uint bal1 = tokenTwo.balanceOf(address(this));

        amount0 = (_shares * bal0) / totalSupply;
        amount1 = (_shares * bal1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "amount0 or amount1 = 0");

        _burn(msg.sender, _shares);
        _update(bal0 - amount0, bal1 - amount1);

        tokenOne.transfer(msg.sender, amount0);
        tokenTwo.transfer(msg.sender, amount1);
    }

    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint amount);
    event Approval(address indexed owner, address indexed spender, uint amount);
}