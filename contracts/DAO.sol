// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//pragma experimental ABIEncoderV2;
import "./openzeppelin/Ownable.sol";
import "./openzeppelin/SafeMath.sol";
import "./GovernanceToken.sol";
import "./VoteMachine.sol";
import "./assetFactory.sol";



contract DAO is Ownable{
	using SafeMath for uint256;
	VoteMachine public voteMachine;
	address voteMachineAddress;
	address rewardsMachineAddress;
	address assetFactoryAddress;
	GovernanceToken public governanceToken;
	AssetFactory public assetFactory;
	uint256 public numberOfGrantVotes;
	uint256 public numberOfNewAssetVotes;
	address[] public grantVoteAddresses;
	string[] public newAssetVoteSymbols;
	uint256 DAOVolume = 100000000 * (10 ** 18) * 10 / 100;

    struct grantFundingVote{
		address votingAddress;
		bool voted;
		uint256 yesVotes;
		uint256 noVotes;
	}

	struct grantFundingVotes {
    	uint256 startingTime;
        uint256 endingTime;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 amount;
        string description;
    	bool open;
    	bool exists;
    	mapping (address => bool) hasvoted;
    	uint256 voteNumber;
    	grantFundingVote[] individualVotes;
    }

	mapping(address => grantFundingVotes) public getGrantVotes;

	struct newAssetVote{
		address votingAddress;
		bool voted;
		uint256 yesVotes;
		uint256 noVotes;
	}

	struct newAssetVotes {
    	uint256 startingTime;
        uint256 endingTime;
        uint256 yesVotes;
        uint256 noVotes;
        string symbol;
        string name;
        string description;
        uint256 upperLimit;
    	bool open;
    	bool exists;
    	mapping (address => bool) hasvoted;
    	uint256 voteNumber;
    	newAssetVote[] individualVotes;
    }

	mapping(string => newAssetVotes) public getNewAssetVotes;

	constructor(GovernanceToken _governanceToken, VoteMachine _voteMachine, AssetFactory _assetFactory) Ownable() {
		governanceToken = _governanceToken;
		voteMachine = _voteMachine;
		assetFactory = _assetFactory;
	}
	
	/**
    * @notice A method that sets the VoteMachine contract address
    * @param _address Address of the VoteMachine contract
    */
    function setVoteMachineAddress (
		address _address
		)
		external 
		onlyOwner
		{
		voteMachineAddress = _address;
	}
	

	/**
    * @notice A method that sets the RewardsMachine contract address
    * @param _address Address of the RewardsMachine contract
    */
    function setRewardsMachineAddress (
		address _address
		)
		external
		onlyOwner
		{
		rewardsMachineAddress = _address;
	}

	/**
    * @notice A method that sets the RewardsMachine contract address
    * @param _address Address of the RewardsMachine contract
    */
    function setAssetFactorAddress (
		address _address
		)
		external
		onlyOwner
		{
		assetFactoryAddress = _address;
	}
	
	
	/**
    * @notice A method initiates a new voting process if a certain address gets funding.
    * @param _receiver Address that will receive the grant
    *        _amount   Amount of grant in WEI
    *        _description Description for what you request funding
    */
    function initiateGrantFundingVote(
		address _receiver,
		uint256 _amount,
		string calldata _description
		)
		external 
		{
		require (getGrantVotes[_receiver].open == false,'VOTE_OPEN');   //check if the voting process is open
		require (_amount < (100000 * (10**18)),'AMOUNT_TOO_HIGH');
		if (getGrantVotes[_receiver].exists == false){
			numberOfGrantVotes +=1;
    		grantVoteAddresses.push(_receiver);
		}
		DAOVolume = DAOVolume.sub(_amount);
		getGrantVotes[_receiver].startingTime = (block.timestamp);
    	getGrantVotes[_receiver].endingTime = block.timestamp.add(1 days);
    	getGrantVotes[_receiver].yesVotes = 0;
    	getGrantVotes[_receiver].noVotes = 0;
    	getGrantVotes[_receiver].open = true;
    	getGrantVotes[_receiver].exists = true;
    	getGrantVotes[_receiver].amount = _amount;    	
    	getGrantVotes[_receiver].description = _description;
    	

    }



	/**
    * @notice A method that votes if a suggest grant will be given or not
    * @param _receiver Address that has requested a DAO grant
    *.       _vote     True or False aka Yes or No
    */
    function voteGrantFundingVote (
		address _receiver, 
		bool _vote
		)
		external
		{
		require(getGrantVotes[_receiver].exists,'UNKNOWN'); //checks if the grant reqzest exists)
		require(getGrantVotes[_receiver].open,'NOT_OPEN'); //checks is the vote is open)
		require(getGrantVotes[_receiver].endingTime >= block.timestamp, 'VOTE_ENDED'); //checks if the voting period is still open
		require(getGrantVotes[_receiver].hasvoted[msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		uint256 voteNumber = governanceToken.stakeOf(msg.sender);
		governanceToken.lockStakeForVote(msg.sender,getGrantVotes[_receiver].endingTime);
		grantFundingVote memory individualVote;
		individualVote.voted = true;
		individualVote.votingAddress = msg.sender;
		if (_vote == true) {
			getGrantVotes[_receiver].yesVotes = getGrantVotes[_receiver].yesVotes.add(voteNumber);
			individualVote.yesVotes = voteNumber;

		}
		else {
			getGrantVotes[_receiver].noVotes = getGrantVotes[_receiver].noVotes.add(voteNumber);
			individualVote.noVotes = voteNumber;
		}
		getGrantVotes[_receiver].hasvoted[msg.sender] = true;
		getGrantVotes[_receiver].individualVotes.push(individualVote);
		getGrantVotes[_receiver].voteNumber = getGrantVotes[_receiver].voteNumber.add(1);		
	}

	/**
    * @notice A method that checks if an address has already voted in a grant Vote.
    * @param _address Address that is checked
    *        _receiver Address for which the voting process should be checked
    */
    function checkIfVotedGrantFunding(
		address _address, 
		address _receiver
		) 
		external
		view
		returns(bool)
		{
		return (getGrantVotes[_receiver].hasvoted[_address]);
	}

	
	/**
    * @notice A method that closes a specific grant funding voting process.
    * @param _receiver Address for which the voting process should be closed
    */
    function closeGrantFundingVote (
		address _receiver
		)
		external 
		{
		require(getGrantVotes[_receiver].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getGrantVotes[_receiver].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getGrantVotes[_receiver].endingTime < block.timestamp);
		uint256 newRewardpoints = 0;
		getGrantVotes[_receiver].open = false;
		
		
		if (getGrantVotes[_receiver].yesVotes > getGrantVotes[_receiver].noVotes){
			governanceToken.transfer(_receiver,getGrantVotes[_receiver].amount);

			for (uint256 i = 0; i < getGrantVotes[_receiver].voteNumber; i++) {
				voteMachine.addRewardPointsDAO(getGrantVotes[_receiver].individualVotes[i].votingAddress, getGrantVotes[_receiver].individualVotes[i].yesVotes);
				newRewardpoints = newRewardpoints.add(getGrantVotes[_receiver].individualVotes[i].yesVotes);
				}
			}
		else {
			DAOVolume = DAOVolume.add(getGrantVotes[_receiver].amount);
			for (uint256 i = 0; i < getGrantVotes[_receiver].voteNumber; i++) {
				voteMachine.addRewardPointsDAO(getGrantVotes[_receiver].individualVotes[i].votingAddress, getGrantVotes[_receiver].individualVotes[i].noVotes);
        		newRewardpoints = newRewardpoints.add(getGrantVotes[_receiver].individualVotes[i].noVotes);
        	}
		}
		for (uint256 i = 0; i < getGrantVotes[_receiver].voteNumber; i++) {
			address voteAddress = getGrantVotes[_receiver].individualVotes[i].votingAddress;
			delete(getGrantVotes[_receiver].hasvoted[voteAddress]);
		}
		voteMachine.addTotalRewardPointsDAO(newRewardpoints);
		//delete(getGrantVotes[_receiver]);
		
	}

	/**
	* @notice A method that gets the details of a specific grant poposal Vote
	* @param _address Address to check
	*/
	function getGrantVoteDetails(
		address _address
		)
		external
		view
		//returns (uint256,uint256,uint256,uint256,bool,bool,uint256,string memory)
		returns (uint256,uint256,uint256,uint256,string memory,bool)
		{
			//uint256 startingTime = getGrantVotes[_address].startingTime;
			uint256 endingTime = getGrantVotes[_address].endingTime;
			uint256 yesVotes = getGrantVotes[_address].yesVotes;
			uint256 noVotes = getGrantVotes[_address].noVotes;
			uint256 grantAmount = getGrantVotes[_address].amount;
			//bool proposalExists = getGrantVotes[_address].exists;
			string memory description = getGrantVotes[_address].description;
			bool grantVoteOpen = getGrantVotes[_address].open;
			
			return (endingTime,yesVotes,noVotes,grantAmount,description,grantVoteOpen);
		}


	// NEW ASSET CREATION STARTING HERE

    /**
    * @notice A method initiates a new voting process if a certain address gets funding.
    * @param _symbol Symbol of the new asset
    *        _name Name of the new asset
    *        _upperLimit  Upper limit for the new asset
    *        _description Description of the asset
    */
    function initiateNewAssetVote(
		string calldata _symbol,
		string calldata _name,
		uint256 _upperLimit,
		string calldata _description
		)
		external 
		{
		require (getNewAssetVotes[_symbol].open == false,'VOTE_OPEN');   //check if the voting process is open
		require (assetFactory.assetExists(_symbol) == false,'ASSET_EXISTS');
		if (getNewAssetVotes[_symbol].exists == false){
			numberOfNewAssetVotes +=1;
    		newAssetVoteSymbols.push(_symbol);
		}

		getNewAssetVotes[_symbol].startingTime = (block.timestamp);
    	getNewAssetVotes[_symbol].endingTime = block.timestamp.add(1 days);
    	getNewAssetVotes[_symbol].yesVotes = 0;
    	getNewAssetVotes[_symbol].noVotes = 0;
    	getNewAssetVotes[_symbol].open = true;
    	getNewAssetVotes[_symbol].exists = true;
    	getNewAssetVotes[_symbol].name = _name;    	
    	getNewAssetVotes[_symbol].upperLimit = _upperLimit;   	
    	getNewAssetVotes[_symbol].description = _description;
    	
    }


	/**
    * @notice A method that votes if a suggest grant will be given or not
    * @param _symbol Symbol of the new asset that is voted on
    *.       _vote     True or False aka Yes or No
    */
    function voteNewAssetVote (
		string calldata _symbol, 
		bool _vote
		)
		external
		{
		require(getNewAssetVotes[_symbol].exists,'UNKNOWN'); //checks if the newAsset vote exists)
		require(getNewAssetVotes[_symbol].open,'NOT_OPEN'); //checks is the vote is open)
		require(getNewAssetVotes[_symbol].endingTime >= block.timestamp, 'VOTE_ENDED'); //checks if the voting period is still open
		require(getNewAssetVotes[_symbol].hasvoted[msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		uint256 voteNumber = governanceToken.stakeOf(msg.sender);
		governanceToken.lockStakeForVote(msg.sender,getNewAssetVotes[_symbol].endingTime);
		newAssetVote memory individualVote;
		individualVote.voted = true;
		individualVote.votingAddress = msg.sender;
		if (_vote == true) {
			getNewAssetVotes[_symbol].yesVotes = getNewAssetVotes[_symbol].yesVotes.add(voteNumber);
			individualVote.yesVotes = voteNumber;

		}
		else {
			getNewAssetVotes[_symbol].noVotes = getNewAssetVotes[_symbol].noVotes.add(voteNumber);
			individualVote.noVotes = voteNumber;
		}
		getNewAssetVotes[_symbol].hasvoted[msg.sender] = true;
		getNewAssetVotes[_symbol].individualVotes.push(individualVote);
		getNewAssetVotes[_symbol].voteNumber = getNewAssetVotes[_symbol].voteNumber.add(1);		
	}

	/**
    * @notice A method that checks if an address has already voted in a new asset Vote.
    * @param _address Address that is checked
    *        _symbol Symbol of the asset that is checked
    */
    function checkIfVotedNewAsset(
		address _address, 
		string calldata _symbol
		) 
		external
		view
		returns(bool)
		{
		return (getNewAssetVotes[_symbol].hasvoted[_address]);
	}

	
	/**
    * @notice A method that closes a specific new asset voting process.
    * @param _symbol Symbol of the potential new asset for which the voting process should be closed
    */
    function closeNewAssetVote (
		string calldata _symbol
		)
		external 
		{
		require(getNewAssetVotes[_symbol].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getNewAssetVotes[_symbol].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getNewAssetVotes[_symbol].endingTime < block.timestamp);
		uint256 newRewardpoints = 0;
		getNewAssetVotes[_symbol].open = false;
		
		
		if (getNewAssetVotes[_symbol].yesVotes > getNewAssetVotes[_symbol].noVotes){
			// HIER DAS REIN WAS ER MACHEN SOLL
			assetFactory.createAssets(getNewAssetVotes[_symbol].name,_symbol,getNewAssetVotes[_symbol].description,getNewAssetVotes[_symbol].upperLimit);
			

			for (uint256 i = 0; i < getNewAssetVotes[_symbol].voteNumber; i++) {
				voteMachine.addRewardPointsDAO(getNewAssetVotes[_symbol].individualVotes[i].votingAddress, getNewAssetVotes[_symbol].individualVotes[i].yesVotes);
				newRewardpoints = newRewardpoints.add(getNewAssetVotes[_symbol].individualVotes[i].yesVotes);
				}
			}
		else {
			for (uint256 i = 0; i < getNewAssetVotes[_symbol].voteNumber; i++) {
				voteMachine.addRewardPointsDAO(getNewAssetVotes[_symbol].individualVotes[i].votingAddress, getNewAssetVotes[_symbol].individualVotes[i].noVotes);
        		newRewardpoints = newRewardpoints.add(getNewAssetVotes[_symbol].individualVotes[i].noVotes);
        	}
		}
		for (uint256 i = 0; i < getNewAssetVotes[_symbol].voteNumber; i++) {
			address voteAddress = getNewAssetVotes[_symbol].individualVotes[i].votingAddress;
			delete(getNewAssetVotes[_symbol].hasvoted[voteAddress]);
		}
		voteMachine.addTotalRewardPointsDAO(newRewardpoints);
		//delete(getNewAssetVotes[_symbol]);
		
	}
    //END

}
