// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "./openzeppelin/Ownable.sol";
import "./openzeppelin/SafeMath.sol";
import "./MarketFactory.sol";
import "./GovernanceToken.sol";
import "./VoteMachine.sol";
//import "./issuaaLibrary.sol";
import "./interfaces/IMarketPair.sol";
import "./assetFactory.sol";

contract RewardsMachine is Ownable{
	using SafeMath for uint256;
    uint256 public nextRewardsPayment;
    uint256 public currentINTSupply;
    uint256 public maxINTSupply;
    
    uint256 public rewardsRound;
    mapping (address => uint256) public lastRewardsRound;

    GovernanceToken public governanceToken;
    VoteMachine public voteMachine;
    
    
	address public master;
	address private USDTaddress = 0x03ae85a5F1405ab5e1047B8476EDbB5917f75428;
    address voteMachineAddress;
    address assetFactoryAddress;
    address marketFactoryAddress;
    uint256 public assetNumber;
    uint256 public vestingPeriod;
    string[] public assets;
    uint256 public LPRewardTokenNumber;
    uint256 public votingRewardTokenNumber;
    uint256 public stakingRewardPoints;
    bool IPTBonusPoolAdded = false;

    address[] public pools;
    mapping(string =>bool) public poolExists;
    uint256 public numberOfPools;
	mapping(address => uint256) public stakingRewardsPoints;   
	address[] public stakers;

	constructor(GovernanceToken _governanceToken) Ownable() {
		governanceToken = _governanceToken;
		maxINTSupply = 100000000 * (10 ** 18);
		currentINTSupply = 20000000 * (10 ** 18);
		vestingPeriod = 90 days;
  	}
	
	/**
    * @notice A method that set the address of the VoteMachine contract.
    * @param  _address Address of the VoteMachine contract
    */
    function setVoteMachineAddress (
		address _address
		)
		public
		onlyOwner
		{
		voteMachineAddress = _address;
	}

    /**
    * @notice A method that set the address of the VoteMachine contract.
    * @param  _address Address of the VoteMachine contract
    */
    function setMarketFactoryAddress (
        address _address
        )
        public
        onlyOwner
        {
        marketFactoryAddress = _address;
    }

	/**
    * @notice A method that set the address of the AssetFactory contract.
    * @param  _address Address of the AssetFactory contract
    */
    function setAssetFactoryAddress (
		address _address
		) 
		public
		onlyOwner
		{
		assetFactoryAddress = _address;
	}

	
	/**
    * @notice A method that reduced the variable currentINTSupply.
    *         currentINTsupple keeps track of the amount of governace token, which is important
    *         to keep reducing the rewards to ot let the issued amount exceed the max value.
    *         this function is used when givernance tokens are burned.
    * @param  _amount Amount by which the currentINTsupply is reduced.
    */
    function reduceCurrentINTSupply(
		uint256 _amount
		) 
		external 
		{
		require (msg.sender == assetFactoryAddress,'Not authorized');
		currentINTSupply = currentINTSupply.sub(_amount);
	}

	/**
    * @notice A method that lets an external contract fetch the current supply of the governance token.
    */
    function getCurrentSupply() 
		external
		view 
		returns (uint256) 
		{
		return (currentINTSupply);
	}

	/**
    * @notice A method that adds a market pair to the list of pools, which will get rewarded.
    * @param  _symbol Address of the asset, for which the new pool is generated
    */
    function addPools(
		string calldata _symbol
		) 
		external
        onlyOwner
		{
		require(poolExists[_symbol] == false,'POOL_EXISTS_ALREADY');
        require(AssetFactory(assetFactoryAddress).assetExists(_symbol),'UNKNOWN_SYMBOL');
        (address token1,address token2) = AssetFactory(assetFactoryAddress).getTokenAddresses(_symbol);
        address pair1 = MarketFactory(marketFactoryAddress).getMarketPair(token1,USDTaddress);
        address pair2 = MarketFactory(marketFactoryAddress).getMarketPair(token2,USDTaddress);
        poolExists[_symbol] = true;
        pools.push(pair1);
        pools.push(pair2);
		numberOfPools +=2;
	}

    /**
    * @notice A method that adds the IPT MarketPool.
    * @param  _poolAddress Address of the pool, for which the new pool is generated
    */
    function addIPTBonusPool(
        address _poolAddress
        ) 
        external
        
        {
        require(IPTBonusPoolAdded == false,'POOL_EXISTS_ALREADY');
        
        pools.push(_poolAddress);
        numberOfPools +=1;
        IPTBonusPoolAdded = true;
    }
    

    /**
    * @notice A method that creates the weekly reward tokens. Can only be called once per week.
    */
    function createRewards() 
    	external 
    	{
    	require(nextRewardsPayment<block.timestamp,'TIME_NOT_UP');
    	uint256 weeklyRewards = maxINTSupply.sub(currentINTSupply).div(20);
    	votingRewardTokenNumber = weeklyRewards.mul(20).div(100);
    	LPRewardTokenNumber = weeklyRewards.mul(80).div(100);

    	//SNAPSHOT FOR THE LP TOKEN HOLDERS
	    for (uint256 s = 0; s < numberOfPools; s += 1){
	    	address poolAddress = pools[s];
	    	IMarketPair(poolAddress).createSnapShot();
	    }

	    nextRewardsPayment = block.timestamp.add(1 days);
	    VoteMachine(voteMachineAddress).resetRewardPoints();
	    rewardsRound = rewardsRound.add(1);
    }


    /**
    * @notice A method that claims the rewards for the calling address.
    */
    function claimRewards()
    	external
        returns (uint256)
    	{
    		require (lastRewardsRound[msg.sender]<rewardsRound,'CLAIMED_ALREADY');
    		lastRewardsRound[msg.sender] = rewardsRound;
    		//Voting rewards
    		uint256 votingRewardPoints = VoteMachine(voteMachineAddress).rewardPointsOf(msg.sender);
    		uint256 totalVotingRewardPoints = VoteMachine(voteMachineAddress).getTotalRewardPoints();
    		uint256 votingRewards;
    		if (totalVotingRewardPoints > 0) {
    			votingRewards = votingRewardTokenNumber.mul(votingRewardPoints).div(totalVotingRewardPoints);	
    		}
    		else {
    			votingRewards = 0;
    		}
    		
    		
    		
    		//LP Rewards
    		uint256 LPRewards;

    		for (uint256 s = 0; s < numberOfPools; s += 1){
	    		address poolAddress = pools[s];
	    		uint256 rewards;
	    		uint256 snapshotID = IMarketPair(poolAddress).snapshotID();
	    		
	    		uint256 LPTokenBalance = IMarketPair(poolAddress).balanceOfAt(msg.sender, snapshotID);
	    		uint256 LPTokenTotalSupply = IMarketPair(poolAddress).totalSupplyAt(snapshotID);

	    		uint256 poolRewards = LPRewardTokenNumber.div(numberOfPools);
	    		if (LPTokenTotalSupply >0){
	    			rewards = poolRewards.mul(LPTokenBalance).div(LPTokenTotalSupply);
	    			}
	    		else{
	    			rewards = 0;	
	    		}
	    		
	    		LPRewards = LPRewards.add(rewards);
            }
    		
    		

    		uint256 totalRewards = votingRewards.add(LPRewards);
    		currentINTSupply = currentINTSupply.add(totalRewards);
    		governanceToken.mintAndVest(msg.sender, totalRewards.mul(80).div(100),vestingPeriod);
		    governanceToken.mint(msg.sender, totalRewards.mul(20).div(100));
			return (totalRewards);

    	}

    /**
    * @notice A method that gets the pending rewards for a specific address.
    * @param  _address Address for the pending rewards are checked
    */
    function getRewards(address _address)
    	external
    	view
        returns (uint256)
    	{
    		if (lastRewardsRound[_address]>=rewardsRound){return 0;}
    		
    		//Voting rewards
    		uint256 votingRewardPoints = VoteMachine(voteMachineAddress).rewardPointsOf(_address);
    		uint256 totalVotingRewardPoints = VoteMachine(voteMachineAddress).getTotalRewardPoints();
    		uint256 votingRewards;
    		if (totalVotingRewardPoints > 0) {
    			votingRewards = votingRewardTokenNumber.mul(votingRewardPoints).div(totalVotingRewardPoints);	
    		}
    		else {
    			votingRewards = 0;
    		}
    		
    		
    		
    		//LP Rewards
    		uint256 LPRewards;

    		for (uint256 s = 0; s < numberOfPools; s += 1){
	    		address poolAddress = pools[s];
	    		uint256 rewards;
	    		uint256 snapshotID = IMarketPair(poolAddress).snapshotID();
	    		
	    		uint256 LPTokenBalance = IMarketPair(poolAddress).balanceOfAt(_address, snapshotID);
	    		uint256 LPTokenTotalSupply = IMarketPair(poolAddress).totalSupplyAt(snapshotID);

	    		uint256 poolRewards = LPRewardTokenNumber.div(numberOfPools);
	    		if (LPTokenTotalSupply >0){
	    			rewards = poolRewards.mul(LPTokenBalance).div(LPTokenTotalSupply);
	    			}
	    		else{
	    			rewards = 0;	
	    		}
	    		
	    		LPRewards = LPRewards.add(rewards);
            }
    		
    		

    		uint256 totalRewards = votingRewards.add(LPRewards);
    		return (totalRewards);

    	}
}
