// SPDX-License-Identifier: MIT

// The market functionality has been largely forked from uiswap.
// Adaptions to the code have been made, to remove functionality that is not needed,
// or to adapt to the remaining code of this project.
// For the original uniswap contracts plese see:
// https://github.com/uniswap
//

pragma solidity ^0.8.0;
import "./interfaces/IERC20I.sol";
import "./interfaces/IMarketFactory.sol";
import "./openzeppelin/Math.sol";
import './MarketERC20.sol';


contract MarketPair is MarketERC20{
	
	using SafeMath for uint256;


	bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
	bytes4 private constant SELECTOR1 = bytes4(keccak256(bytes('transfer(address,uint256)')));
    uint256 private reserve0;           // uses single storage slot, accessible via getReserves
    uint256 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast;
    address INTAddress;
    address tokenFactoryAddress;
    address public token0;
    address public token1;
    address public factory;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event
   
    uint256 public constant MINIMUM_LIQUIDITY = 10**3;
    address rewardsMachineAddress;
    address[] public holdersSnapShot;
    




	constructor()   {
		factory = msg.sender;
        }
	
  	// called once by the factory at time of deployment
    function initialize(
        address _token0, 
        address _token1,
        address _rewardsMachineAddress)
        external 
        {
        require(msg.sender == factory, 'FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
        rewardsMachineAddress = _rewardsMachineAddress;
    }

  	event Mint(
        address indexed sender, 
        uint256 amount0, 
        uint256 amount1
    );

    event Burn(
        address indexed sender, 
        uint256 amount0, 
        uint256 amount1, 
        address indexed to
    );

    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    event Sync(
        uint256 reserve0, 
        uint256 reserve1
    );


	function _safeTransferFrom(
        address token, 
        address from, 
        address to, 
        uint256 value
        ) 
        private 
        {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

	function _safeTransfer(
        address token, 
        address to, 
        uint256 value
        ) 
        private 
        {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR1, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TRANSFER_FAILED');
    }

    function getReserves()
        public 
        view 
        returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast) 
        {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    // update reserves
    function _update(
        uint256 balance0, 
        uint256 balance1
        ) 
        private
        {
        reserve0 = balance0;
        reserve1 = balance1;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrtu(k)
    function _mintFee(
        uint256 _reserve0, 
        uint256 _reserve1
        ) 
        private 
        returns (bool feeOn) 
        {
        address feeTo = IMarketFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrtu(uint(_reserve0).mul(_reserve1));
                uint256 rootKLast = Math.sqrtu(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply().mul(rootK.sub(rootKLast));
                    uint256 denominator = rootK.mul(5).add(rootKLast);
                    uint256 liquidity = (numerator) / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
        return feeOn;
    }




    // this low-level function should be called from a contract which performs important safety checks
    function mint(
        address to
        ) 
        external 
        returns (uint256 liquidity) 
        {
        (uint256 _reserve0, uint256 _reserve1,) = getReserves();
        uint256 balance0 = IERC20I(token0).balanceOf(address(this));
        uint256 balance1 = IERC20I(token1).balanceOf(address(this));
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = (Math.sqrtu(amount0.mul(amount1)))-(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'INSUFFICIENT_LIQ');
        _mint(to, liquidity);

        _update(balance0, balance1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
        return (liquidity);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(
        address to
        ) 
        external 
        returns (uint256 amount0, uint256 amount1) 
        {
        (uint256 _reserve0, uint256 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint256 balance0 = IERC20I(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20I(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'INSUFF_LIQ_BURN');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20I(_token0).balanceOf(address(this));
        balance1 = IERC20I(_token1).balanceOf(address(this));

        _update(balance0, balance1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
        return (amount0, amount1);
    }


    // this low-level function should be called from a contract which performs important safety checks
    function swap(
        uint256 amount0Out, 
        uint256 amount1Out, 
        address to
        ) 
        external 
        {
        require(amount0Out > 0 || amount1Out > 0, 'INSUF_OUTPUT');
        (uint256 _reserve0, uint256 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'INSUF_LIQ');

        uint256 balance0;
        uint256 balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        
        balance0 = IERC20I(_token0).balanceOf(address(this));
        balance1 = IERC20I(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'INSUF_INPUT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint256 balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
        uint256 balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
        require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), ': K-FACTOR');
        }

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }



    // this function creates a snapshot, which is used for calculating rewards
    function createSnapShot(
        ) 
        external 
        {
            require (msg.sender == rewardsMachineAddress, 'NOT_ALLOWED1');
            holdersSnapShot = holders;
            _snapshot();

    }

}
