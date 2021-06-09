// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AssetToken.sol";

library issuaaLibrary {
	struct Asset {
    	address Token1; 
    	address Token2; 
    	string name;
    	string symbol;
    	string description;
    	uint256 upperLimit;
    	uint256 endOfLifeValue;
    	uint256 expiryTime;
    	bool frozen;
        bool expired;
    	bool exists;
    }


}
