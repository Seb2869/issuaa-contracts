// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import "./openzeppelin/Ownable.sol";
import "./openzeppelin/SafeMath.sol";
import "./GovernanceToken.sol";
import "./assetFactory.sol";



contract VoteMachine is Ownable{
	using SafeMath for uint256;
	AssetFactory public assetFactory;
	address assetFactoryAddress;
	address rewardsMachineAddress;
	address DAOAddress;
	GovernanceToken public governanceToken;
	uint256 DAOVolume = 100000000 * (10 ** 18) * 10 / 100;
	

	struct Votes{
		address votingAddress;
		bool voted;
		uint256 yesVotes;
		uint256 noVotes;
	}


    struct FreezeVotes {
        uint256 startingTime;
        uint256 endingTime;
        uint256 yesVotes;
        uint256 noVotes;
        bool open;
        bool exists;
        mapping (address => bool) hasvoted;
        uint256 voteNumber;
        Votes[] individualVotes;
    }


    struct endOfLifeVote{
		address votingAddress;
		bool voted;
		uint256 numberOfVotingShares;
		uint256 voteValue;
	}

	struct endOfLifeVotes {
    	uint256 startingTime;
    	uint256 endingTime;
    	uint256 numberOfVotingShares;
    	uint256 totalVoteValue;
    	bool open;
    	bool exists;
    	mapping (address => bool) hasvoted;
    	uint256 voteNumber;
    	endOfLifeVote[] individualVotes;
    }

    struct rewardPointsSnapshot {
    	mapping (address => uint256) votingRewardpoints;
    	address[] votingRewardAddresses;
    	uint256 totalVotingRewardPoints;
    }

    

    mapping (uint256 => rewardPointsSnapshot) internal rewardPointsSnapshots;
    uint256 public currentRewardsRound = 0;

    mapping(string => FreezeVotes) public getFreezeVotes;
    mapping(string => endOfLifeVotes) public getEndOfLifeVotes;
    mapping (address => uint256) public rewardPoints;
    
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

	constructor(GovernanceToken _governanceToken, AssetFactory _assetFactory) Ownable() {
		governanceToken = _governanceToken;
		assetFactory = _assetFactory;
	}
	
	/**
    * @notice A method that sets the AssetFactory contract address
    * @param _address Address of the AssetFactory contract
    */
    function setAssetFactoryAddress (
		address _address
		)
		external 
		onlyOwner
		{
		assetFactoryAddress = _address;
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
    * @notice A method that sets the DAO contract address
    * @param _address Address of the DAO contract
    */
    function setDAOAddress (
		address _address
		)
		external 
		onlyOwner
		{
		DAOAddress = _address;
	}

	/**
    * @notice A method initiates a new voting process that determines if an asset is frozen.
    * @param _symbol Symbol of the asset that is voted on
    */
    function initiateFreezeVote(
		string calldata _symbol
		)
		external 
		{
		require (assetFactory.assetExists(_symbol),'ASSET_UNKNOWN'); //check if the symbol already exists
		require (getFreezeVotes[_symbol].open == false,'VOTE_IS_OPEN');   //check if the voting process is open
		getFreezeVotes[_symbol].startingTime = (block.timestamp);
    	getFreezeVotes[_symbol].endingTime = block.timestamp.add(2 days);
    	getFreezeVotes[_symbol].yesVotes = 0;
    	getFreezeVotes[_symbol].noVotes = 0;
    	getFreezeVotes[_symbol].open = true;
    	getFreezeVotes[_symbol].exists = true;
    }


    

	/**
    * @notice A method that votes if an asset should be frozen or not
    * @param _symbol Symbol of the asset that is voted on
    *        _vote Should be set to true when it should be frozen or false if not
    */
    function voteFreezeVote (
		string  calldata _symbol, 
		bool _vote
		)
		external
		{
		require(getFreezeVotes[_symbol].exists,'UNKNOWN'); //checks if the vote id exists)
		require(getFreezeVotes[_symbol].open,'NOT_OPEN'); //checks is the vote is open)
		require(getFreezeVotes[_symbol].endingTime >= block.timestamp, 'VOTE_OPEN'); //checks if the voting period is still open
		require(getFreezeVotes[_symbol].hasvoted[msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		uint256 voteNumber = governanceToken.stakeOf(msg.sender);
		governanceToken.lockStakeForVote(msg.sender,getFreezeVotes[_symbol].endingTime);
		Votes memory individualVote;
		individualVote.voted = true;
		individualVote.votingAddress = msg.sender;
		if (_vote == true) {
			getFreezeVotes[_symbol].yesVotes = getFreezeVotes[_symbol].yesVotes.add(voteNumber);
			individualVote.yesVotes = voteNumber;

		}
		else {
			getFreezeVotes[_symbol].noVotes = getFreezeVotes[_symbol].noVotes.add(voteNumber);
			individualVote.noVotes = voteNumber;
		}
		getFreezeVotes[_symbol].hasvoted[msg.sender] = true;
		getFreezeVotes[_symbol].individualVotes.push(individualVote);
		getFreezeVotes[_symbol].voteNumber = getFreezeVotes[_symbol].voteNumber.add(1);		
	}

	/**
    * @notice A method that checks if an address has already voted in a specific freeze vote.
    * @param _address Address that is checked
    *        _symbol Symbol for which the voting process should be checked
    */
    function checkIfVoted(
		address _address, 
		string calldata _symbol
		) 
		external
		view
		returns(bool)
		{
		return (getFreezeVotes[_symbol].hasvoted[_address]);
	}

	/**
    * @notice A method that checks if an address has already voted in a specific expiry vote.
    * @param _address Address that is checked
    *        _symbol Symbol for which the voting process should be checked
    */
    function checkIfVotedOnExpiry(
		address _address,
		string calldata _symbol
		) 
		external
		view
		returns(bool)
		{
		return(getEndOfLifeVotes[_symbol].hasvoted[_address]);
	}
	
	/**
    * @notice A method that closes a specific freeze voting process.
    * @param _symbol Symbol for which the voting process should be closed
    */
    function closeFreezeVote (
		string calldata _symbol
		)
		external 
		{
		require(getFreezeVotes[_symbol].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getFreezeVotes[_symbol].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getFreezeVotes[_symbol].endingTime < block.timestamp);
		uint256 newRewardpoints = 0;
		getFreezeVotes[_symbol].open = false;
		
		
		if (getFreezeVotes[_symbol].yesVotes > getFreezeVotes[_symbol].noVotes){
			assetFactory.freezeAsset(_symbol);
			for (uint256 i = 0; i < getFreezeVotes[_symbol].voteNumber; i++) {
				addRewardPoints(getFreezeVotes[_symbol].individualVotes[i].votingAddress, getFreezeVotes[_symbol].individualVotes[i].yesVotes);
				newRewardpoints = newRewardpoints.add(getFreezeVotes[_symbol].individualVotes[i].yesVotes);
				}
			}
		else {
			for (uint256 i = 0; i < getFreezeVotes[_symbol].voteNumber; i++) {
				addRewardPoints(getFreezeVotes[_symbol].individualVotes[i].votingAddress, getFreezeVotes[_symbol].individualVotes[i].noVotes);
        		newRewardpoints = newRewardpoints.add(getFreezeVotes[_symbol].individualVotes[i].noVotes);
        	}
		}
		for (uint256 i = 0; i < getFreezeVotes[_symbol].voteNumber; i++) {
			address voteAddress = getFreezeVotes[_symbol].individualVotes[i].votingAddress;
			delete(getFreezeVotes[_symbol].hasvoted[voteAddress]);
		}
		rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints = rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints.add(newRewardpoints);
		delete(getFreezeVotes[_symbol]);
		
	}

	/**
    * @notice A method initiates a new voting process that determines the price of an asset at expiry.
    * @param _symbol Symbol of the asset that is voted on
    */
    function initiateEndOfLifeVote(
		string calldata _symbol
		)
		external
		{
		require (assetFactory.assetExists(_symbol),'ASSET_UNKNOWN'); //check if the symbol already exists
		require (getEndOfLifeVotes[_symbol].open == false,'VOTE_OPEN');
		require(assetFactory.getExpiryPrice(_symbol) < block.timestamp, 'ASSET_NOT_EXPIRED');
		
		getEndOfLifeVotes[_symbol].startingTime = (block.timestamp);
    	getEndOfLifeVotes[_symbol].endingTime = block.timestamp.add(2 days);
    	getEndOfLifeVotes[_symbol].numberOfVotingShares = 0;
    	getEndOfLifeVotes[_symbol].totalVoteValue = 0;
    	getEndOfLifeVotes[_symbol].open = true;
    	getEndOfLifeVotes[_symbol].exists = true;
    	}

	/**
    * @notice A method that votes on the expiry price
    * @param _symbol Symbol of the asset that is voted on
    *        _value Value of the price at expiry
    */
    function voteOnEndOfLifeValue (
		string  calldata _symbol,
		uint256 _value
		) 
		external
		{
		require(getEndOfLifeVotes[_symbol].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getEndOfLifeVotes[_symbol].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getEndOfLifeVotes[_symbol].endingTime >= block.timestamp, 'VOTE_OVER'); //checks if the voting period is still open
		require(getEndOfLifeVotes[_symbol].hasvoted[msg.sender] == false, 'ALREADY_VOTED');
		require(_value < assetFactory.getUpperLimit(_symbol), 'EXCEEDS_UPPERLIMIT');
		uint256 voteNumber = governanceToken.stakeOf(msg.sender);
		governanceToken.lockStakeForVote(msg.sender,getEndOfLifeVotes[_symbol].endingTime);
		endOfLifeVote memory individualVote;
		individualVote.voted = true;
		individualVote.votingAddress = msg.sender;
		individualVote.numberOfVotingShares = voteNumber;
		individualVote.voteValue = _value;

		getEndOfLifeVotes[_symbol].numberOfVotingShares = getEndOfLifeVotes[_symbol].numberOfVotingShares.add(voteNumber);
		getEndOfLifeVotes[_symbol].totalVoteValue = getEndOfLifeVotes[_symbol].totalVoteValue.add(voteNumber.mul(_value));

		getEndOfLifeVotes[_symbol].hasvoted[msg.sender] = true;
		getEndOfLifeVotes[_symbol].individualVotes.push(individualVote);
		getEndOfLifeVotes[_symbol].voteNumber = getFreezeVotes[_symbol].voteNumber.add(1);		
	}

	/**
    * @notice A method that closes a specific expiry voting process.
    * @param _symbol Symbol for which the voting process should be closed
    */
    function closeEndOfLifeVote (
		string calldata _symbol
		)
		external
		{
		require(getEndOfLifeVotes[_symbol].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getEndOfLifeVotes[_symbol].open,'VOTE_NOT_OPEN'); //checks if the vote is open)
		require(getEndOfLifeVotes[_symbol].endingTime < block.timestamp);  //checks if the voting period is over
		uint256 newRewardpoints;
		uint256 endOfLiveValue;
		getEndOfLifeVotes[_symbol].open = false;
		if (getEndOfLifeVotes[_symbol].numberOfVotingShares != 0) {
			 endOfLiveValue = getEndOfLifeVotes[_symbol].totalVoteValue.div(getEndOfLifeVotes[_symbol].numberOfVotingShares);
		}
		else {endOfLiveValue =  0;}
		assetFactory.setEndOfLifeValue(_symbol,endOfLiveValue);
		
		for (uint256 i = 0; i < getEndOfLifeVotes[_symbol].voteNumber; i++) {
			if (
				getEndOfLifeVotes[_symbol].individualVotes[i].voteValue > endOfLiveValue.mul(99).div(100) 
				&& 
				getEndOfLifeVotes[_symbol].individualVotes[i].voteValue < endOfLiveValue.mul(101).div(100) 
				)
			{
				addRewardPoints(getEndOfLifeVotes[_symbol].individualVotes[i].votingAddress, getEndOfLifeVotes[_symbol].individualVotes[i].numberOfVotingShares);
				newRewardpoints = newRewardpoints.add(getEndOfLifeVotes[_symbol].individualVotes[i].numberOfVotingShares);
			}
		}
		
		for (uint256 i = 0; i < getEndOfLifeVotes[_symbol].voteNumber; i++) {
			address voteAddress = getEndOfLifeVotes[_symbol].individualVotes[i].votingAddress;
			delete(getEndOfLifeVotes[_symbol].hasvoted[voteAddress]);
		}
		rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints = rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints.add(newRewardpoints);
		delete(getEndOfLifeVotes[_symbol]);
	}

	/**
    * @notice A method to check if an address is on the list to receive rewards.
    * @param _address The address to verify.
    * @return bool, uint256 Whether the address is valid to receive rewards,
    * and if so its position in the stakeholders array.
    */
   	function isGettingRewards(
   		address _address
   		)
       	internal
       	view
       	returns(bool, uint256)
   		{
	    for (uint256 s = 0; s < rewardPointsSnapshots[currentRewardsRound].votingRewardAddresses.length; s += 1){
	    	if (_address == rewardPointsSnapshots[currentRewardsRound].votingRewardAddresses[s]) return (true, s);
       	}
       	return (false, 0);
   	}

    /**
    * @notice A method to add a rewards getting address.
    * @param _address The address to add.
    */
   	function addRewardAddress(
   		address _address
   		)
       	internal
   		{
       	(bool _isGettingRewards, ) = isGettingRewards(_address);
       	if(!_isGettingRewards) rewardPointsSnapshots[currentRewardsRound].votingRewardAddresses.push(_address);
   		}	
   	
   	
   	/**
    * @notice A method to retrieve the reward points for an address.
    * @param _address The address to retrieve the stake for.
    * @return uint256 The amount of earned rewards points.
    */
   	function rewardPointsOf(
   		address _address
   		)
    	external
       	view
       	returns(uint256)
   		{
       	return rewardPointsSnapshots[currentRewardsRound.sub(1)].votingRewardpoints[_address];
   	}

   	function addRewardPoints(
   		address _address, 
   		uint256 _amount
   		)
    	internal
   		{
	       	if(rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address] == 0) addRewardAddress(_address);
	       	rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address] = rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address].add(_amount);
   	}

   	/**
    * @notice A method to add  reward points for an address. Can only be called by the DAO contract.
    * @param _address The address to retrieve the stake for.
    + @param _amount The amount of reward points to be added
    */	
   	function addRewardPointsDAO(
   		address _address, 
   		uint256 _amount
   		)
    	external
   		{
	       	require (msg.sender == DAOAddress);
	       	if(rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address] == 0) addRewardAddress(_address);
	       	rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address] = rewardPointsSnapshots[currentRewardsRound].votingRewardpoints[_address].add(_amount);
   	}

   	/**
    * @notice A method to add  total reward points. Can only be called by the DAO contract.
    + @param _amount The amount of total reward points to be added
    */	
   	function addTotalRewardPointsDAO(
   		uint256 _amount
   		)
    	external
   		{
	       	require (msg.sender == DAOAddress);
	       	rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints = rewardPointsSnapshots[currentRewardsRound].totalVotingRewardPoints.add(_amount);
   	}


   	/**
    * @notice A method to get the number of address that get voting reward points.
    */
       	function getNumberOfRewardAddresses() 
   		external
   		view
   		returns(uint256)
   		{
   			return (rewardPointsSnapshots[currentRewardsRound.sub(1)].votingRewardAddresses.length);
   	}

   	function getTotalRewardPoints()
	   	external
	   	view
	   	returns(uint256)
	   	{
	   		return (rewardPointsSnapshots[currentRewardsRound.sub(1)].totalVotingRewardPoints);
   	}

   	/**
    * @notice A method to reset all reward points to zero.
    */
   	function resetRewardPoints () 
    	external
   		{
	       	require (msg.sender == rewardsMachineAddress,'NOT_ALLOWED');
	       	currentRewardsRound = currentRewardsRound +1;
	}

}
