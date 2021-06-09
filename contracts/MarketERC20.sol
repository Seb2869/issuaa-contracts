// SPDX-License-Identifier: MIT

// The market functionality has been largely forked from uiswap.
// Adaptions to the code have been made, to remove functionality that is not needed,
// or to adapt to the remaining code of this project.
// For the original uniswap contracts plese see:
// https://github.com/uniswap
//

pragma solidity ^0.8.0;

import "./openzeppelin/SafeMath.sol";
import "./openzeppelin/ERC20Snapshot.sol";


contract MarketERC20 is ERC20Snapshot{
    using SafeMath for uint256;

    string public override constant name = 'ISSUAA LP Token';
    string public override constant symbol = 'ILPT';
    uint8 public override constant decimals = 18;

    
    uint256 public numberOfHolders;
    address[] public holders;
    
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

    constructor() ERC20(name, symbol) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }






    // allows transfer to zero instead of the normal ERC20 _mint function
    function _mint(address account, uint256 amount) internal override {
        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    

    /**
    * @notice A method that checks if an address hold the token.
    * @param _address Address to check
    */
    function isHolder(
        address _address
        ) 
        public 
        view 
        returns(bool, uint256) 
        {
        for (uint256 s = 0; s < holders.length; s += 1){
           if (_address == holders[s]) return (true, s);
        }
        return (false, 0);
    }

    /**
    * @notice A method that adds an address to the holders list.
    * @param _address Address to add
    */
    function addHolder(
        address _address
        ) 
        internal 
        {
        (bool _isHolder, ) = isHolder(_address);
        if(!_isHolder) holders.push(_address);
    }

    /**
    * @notice A method that removes an address from the holders list.
    * @param _address Address to remove
    */
    function removeHolder(
        address _address
        ) 
        internal 
        {
        (bool _isHolder, uint256 s) = isHolder(_address);
        if(_isHolder){
        holders[s] = holders[holders.length - 1];
                holders.pop();
        }
    }

    /*
    function permit(
        address owner, 
        address spender, 
        uint256 value, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
        ) 
        external 
        {
        require(deadline >= block.timestamp, 'EXPIRED');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
    */
}
