// SPDX-License-Identifier: MIT

// The market functionality has been largely forked from uiswap.
// Adaptions to the code have been made, to remove functionality that is not needed,
// or to adapt to the remaining code of this project.
// For the original uniswap contracts plese see:
// https://github.com/uniswap
//

pragma solidity ^0.8.0;


import "./openzeppelin/SafeMath.sol";
import './interfaces/IMarketFactory.sol';
import './interfaces/IMarketRouter01.sol';
import './libraries/TransferHelper.sol';
import './MarketFactory.sol';
//import './interfaces/IERC20I.sol';

import './libraries/MarketLibrary.sol';

contract MarketRouter is IMarketRouter01 {
    using SafeMath for uint;

    address public immutable override factory;
    

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'EXPIRED');
        _;
    }

    constructor(address _factory) {
        factory = _factory;
       
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
        )
        internal 
        virtual 
        returns (uint256 amountA, uint256 amountB) 
        {
        // create the pair if it doesn't exist yet
        if (MarketFactory(factory).getMarketPair(tokenA, tokenB) == address(0)) {
            MarketFactory(factory).createPair(tokenA, tokenB);
        }

        (uint256 reserveA, uint256 reserveB) = getPairReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = MarketLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = MarketLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    

    function sortPairTokens(
        address tokenA, 
        address tokenB
        )  
        internal 
        pure 
        returns (address token0, address token1) 
        {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');
        return (token0, token1);
    }



    // fetches and sorts the reserves for a pair
    function getPairReserves(
        address tokenA,
        address tokenB
        ) 
        internal
        view 
        returns (uint256 reserveA, uint256 reserveB) 
        {
        (address token0,) = sortPairTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IMarketPair(getMarketPair(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getMarketPair(
        address tokenA, 
        address tokenB
        )
        public
        view
        returns (address) 
        {
        address pair = MarketFactory(factory).getMarketPair(tokenA, tokenB);
        return pair;
    }



    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
        ) 
        external 
        virtual 
        override 
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity) 
        {
            (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
            address pair = getMarketPair(tokenA, tokenB);
            TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
            TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
            liquidity = IMarketPair(pair).mint(to);
            return(amountA,amountB,liquidity);
    }


    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
        )
        external 
        virtual
        override 
        ensure(deadline) 
        returns (uint256 amountA, uint256 amountB) 
        {
        address pair = (MarketFactory(factory).getMarketPair(tokenA, tokenB));
        IMarketPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IMarketPair(pair).burn(to);
        (address token0,) = sortPairTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'INSUFFICIENT_B_AMOUNT');
        return (amountA,amountB);
    }
    

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts, 
        address[] memory path, 
        address _to
        ) 
        internal
        virtual 
        {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = sortPairTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? getMarketPair(output, path[i + 2]) : _to;
            IMarketPair(getMarketPair(input, output)).swap(
                amount0Out, amount1Out, to
            );
        }
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        uint256 amountIn, 
        address[] memory path
        )
        public
        view
        returns (uint[] memory) 
        {
        require(path.length >= 2, 'MarketLibrary: INVALID_PATH');
        uint256[] memory amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getPairReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
        return amounts;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
        )
        external
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory) 
        {
        uint256[] memory amounts = getAmountsOut(amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
        address token = path[0];
        address from = msg.sender;
        address pair = MarketFactory(factory).getMarketPair(path[0], path[1]);
        uint256 amount = amounts[0];
        TransferHelper.safeTransferFrom(token, from, pair, amount);
        _swap(amounts, path, to);
        return (amounts);
    }


    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn, 
        uint256 reserveIn, 
        uint256 reserveOut
        )
        public 
        pure 
        returns (uint256 amountOut) 
        {
        require(amountIn > 0, 'MarketLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'MarketLibrary: INSUFFICIENT_LIQUIDITY');
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
        return amountOut;
    }

    
    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA, 
        uint256 reserveA, 
        uint256 reserveB
        ) 
        public 
        pure 
        virtual 
        override 
        returns (uint256 amountB) 
        {
        return MarketLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountIn(
        uint256 amountOut, 
        uint256 reserveIn, 
        uint256 reserveOut
        )
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
        {
        return MarketLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsIn(
        uint256 amountOut, 
        address[] memory path
        )
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
        {
        return MarketLibrary.getAmountsIn(factory, amountOut, path);
    }


}
