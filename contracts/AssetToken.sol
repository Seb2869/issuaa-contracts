// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./openzeppelin/Ownable.sol";
import "./openzeppelin/ERC20.sol";

contract AssetToken is Ownable, ERC20 {
//	string public _name;
//	string public _symbol;


    constructor (
    	string memory _name, 
    	string memory _symbol, 
    	string memory _description, 
    	uint256 _upperLimit
    	)
    	 
    	ERC20(_name,_symbol)
    	{}

    /**
	* @notice A method that mints new tokens. Can only be called by the owner, which is the token factory contract.
	* @param _account Address of the account that receives the tokens.
	*        _amount Amount of tokens to be minted (in WEI).
	*/
	function mint(
    	address _account, 
    	uint256 _amount
    	) 
    	external 
    	onlyOwner 
    	{
        _mint(_account, _amount);
    }

    /**
	* @notice A method that burns tokens. Can only be called by the owner, which is the token factory contract.
	* @param _account Address of the account that burns the tokens.
	*        _amount Amount of tokens to be burned (in WEI).
	*/
	function burn(
    	address _account, 
    	uint256 _amount
    	) 
    	external 
    	onlyOwner 
    	{
        _burn(_account, _amount);
    }

    
}
