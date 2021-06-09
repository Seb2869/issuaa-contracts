// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./openzeppelin/Ownable.sol";
import "./openzeppelin/ERC20.sol";
import "./openzeppelin/SafeMath.sol";

contract GovernanceToken is Ownable, ERC20 {
  using SafeMath for uint256;

  address voteMachineAddress;
  address DAOAddress;

  address[] internal stakeholders;

  mapping(address => uint256) internal stakes;

  mapping(address => uint256[2][]) public vestingSchedules;

  mapping(address => uint256) public totalEscrowedAccountBalance;

  mapping(address => uint256) public totalVestedAccountBalance;


  uint256 public totalEscrowedBalance;



  constructor () ERC20("Issuaa Network Token", "IPT") {    
    _mint(msg.sender, 100000000 * (10 ** 18) * 10 / 100);
  }

  /**
  * @notice A method that sets the address of the vote machine contract.
  * @param _address Address of the vote machine contract.
  */
  function setVoteMachineAddress(
    address _address
    ) 
    external 
    onlyOwner 
    {
    voteMachineAddress = _address;
    }

  /**
  * @notice A method that sets the address of the DAO contract.
  * @param _address Address of the DAO contract.
  */
  function setDAOAddress(
    address _address
    ) 
    external 
    onlyOwner 
    {
    DAOAddress = _address;
    }


  /**
  * @notice A method that mints new governance tokens. Can only be called by the owner.
  * @param _address Address that receives the governance tokens.
  *        _amount Amount to governance tokens to be minted in WEI.
  */
  function mint(
    address _address, 
    uint256 _amount
    ) 
    external 
    onlyOwner 
    {
  	_mint(_address, _amount);
  }

  /**
  * @notice A method that mints and automatically vests new governance tokens. Can only be called by the owner.
  * @param _address Address that receives the governance tokens.
  *        _amount Amount to governance tokens to be minted in WEI.
  */
  function mintAndVest(
    address _address,
    uint256 _amount, 
    uint256 _time
    ) 
    external 
    onlyOwner 
    {
    if (stakes[_address] == 0) addStakeholder(_address);
  	stakes[_address] = stakes[_address].add(_amount);
  	vestingSchedules[_address].push([block.timestamp.add(_time),_amount]);
  }

  /**
  * @notice A method that burns governance tokens. Can only be called by the owner.
  * @param _address Address that receives the governance tokens.
  *        _amount Amount to governance tokens to be minted in WEI.
  */
  function burn(
    address _address,
    uint256 _amount
    ) 
    external 
    onlyOwner {
    _burn(_address, _amount);
  }

  /**
  * @notice A method to check if an address is a stakeholder.
  * @param _address The address to verify.
  * @return bool, uint256 Whether the address is a stakeholder,
  * and if so its position in the stakeholders array.
  */
  function isStakeholder(
    address _address
    )
    public
    view
    returns(bool, uint256)
  	{
    for (uint256 s = 0; s < stakeholders.length; s += 1){
    	if (_address == stakeholders[s]) return (true, s);
     }
     return (false, 0);
  }

  /**
  * @notice A method to add a stakeholder.
  * @param _stakeholder The stakeholder to add.
  */
  function addStakeholder(
    address _stakeholder
    )
  	internal
  	{
     	(bool _isStakeholder, ) = isStakeholder(_stakeholder);
     	if(!_isStakeholder) stakeholders.push(_stakeholder);
   }


  /**
  * @notice A method to remove a stakeholder.
  * @param _stakeholder The stakeholder to remove.
  */
  function removeStakeholder(
    address _stakeholder
    )
  	internal
  	{
   	(bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
   	if(_isStakeholder){
    	stakeholders[s] = stakeholders[stakeholders.length - 1];
       	stakeholders.pop();
   	}
   }

  /**
  * @notice A method to retrieve the stake for a stakeholder.
  * @param _stakeholder The stakeholder to retrieve the stake for.
  * @return uint256 The amount of wei staked.
  */
  function stakeOf(
    address _stakeholder
    )
  	public
    view
    returns(uint256)
  	{
     	return stakes[_stakeholder];
  }

  /**
  * @notice A method to the aggregated stakes from all stakeholders.
  * @return uint256 The aggregated stakes from all stakeholders.
  */
  function totalStakes()
   	public
   	view
   	returns(uint256)
  	{
   	uint256 _totalStakes = 0;
   	for (uint256 s = 0; s < stakeholders.length; s += 1){
    	_totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
   	}
   	return _totalStakes;
  }

  /**
  * @notice A method for a stakeholder to create a stake.
  * @param _stake The size of the stake to be created.
  */
  function createStake(
    uint256 _stake
    )
  	public
  	{
       	_burn(msg.sender, _stake);
       	if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
       	stakes[msg.sender] = stakes[msg.sender].add(_stake);
  }


  /**
  * @notice A method for a stakeholder to remove a stake.
  * @param _stake The size of the stake to be removed.
  */
  function removeStake(
    uint256 _stake
    )
  	public
  	{
   	uint256 freeStake = stakes[msg.sender] - getVestingStake(msg.sender);
   	
   	require (freeStake >= _stake,'Not enough free stake');

   	stakes[msg.sender] = stakes[msg.sender].sub(_stake);
   	if(stakes[msg.sender] == 0) removeStakeholder(msg.sender);
   	_mint(msg.sender, _stake);

   	for (uint256 i = 0; i < vestingSchedules[msg.sender].length; i += 1){
  		if(vestingSchedules[msg.sender][i][0] < block.timestamp) {delete vestingSchedules[msg.sender][i];}
  	}
  }

  /**
  * @notice A method to get the vesting schedule of a stakeholder
  * @param _stakeholder The address of the the stakeholder
  */
  function vestingSchedule(
    address _stakeholder
    )
  	public
  	view
  	returns(uint256[2][] memory)
  	{
   	uint256[2][] memory schedule = vestingSchedules[_stakeholder];
   	return schedule;
  }
   		
  /**
  * @notice A method to get the currently vesting stake of a stakeholder
  * @param _address The address of the the stakeholder
  */
 	function getVestingStake(
    address _address
    )
 		public
 		view
 		returns (uint256)
 		{
		uint256[2][] memory schedule = vestingSchedule(_address);
 		uint256 vestedStake = 0;
 		for (uint256 i=0; i < schedule.length;i++){
 		  if (schedule[i][0] > block.timestamp) {vestedStake = vestedStake.add(schedule[i][1]);}
 		  }
 		return vestedStake;
 	}


  /**
  * @notice A method to increase the minimum vesting period to a given timestamp.
  * @param _address The address of the the stakeholder
  *        _timestamp The time until when the vesting is prolonged
  */
  function setMinimumVestingPeriod(
    address _address,
    uint256 _timestamp
    )
    internal
    {
    uint256[2][] memory schedule = vestingSchedule(_address);
    for (uint256 i=0; i < schedule.length;i++){
      if (schedule[i][0] < _timestamp) {vestingSchedules[_address][i][0] = _timestamp;}
      }
    }


  /**
  * @notice A method to get the locked stake of a stakeholder at a given time
  * @param _address The address of the the stakeholder
  * @param _time The time in the future
  */
  function getFutureLockedStake(
    address _address, 
    uint256 _time
    )
    public
    view
    returns (uint256)
    {
    uint256[2][] memory schedule = vestingSchedule(_address);
    uint256 lockedStake = 0;
    for (uint256 i=0; i < schedule.length;i++){
      if (schedule[i][0] > _time) {lockedStake = lockedStake.add(schedule[i][1]);}
      }
    return lockedStake;
  }

 	/**
  * @notice A method for a stakeholder to lock a stake.
  * @param _stake The size of the stake to be vested.
  		 _time The time until the stake becomes free again in seconds
  */
 	function lockStake(
    uint256 _stake, 
    uint256 _time
    )
  	public
 		{
    uint256[2][] memory schedule = vestingSchedule(msg.sender);
    uint256 lockedStake = 0;
    for (uint256 i=0; i>schedule.length;i++){
   	  if (schedule[i][0] > block.timestamp) {lockedStake = lockedStake.add(schedule[i][1]);}
   	  else {delete schedule[i];}
    }
    uint256  currentStake = stakeOf(msg.sender);
    uint256  unlockedStake = currentStake.div(lockedStake);
    require (unlockedStake >= _stake,'Not enough free stake available');
    vestingSchedules[msg.sender].push([block.timestamp.add(_time),_stake]);
  }

  /**
  * @notice A method for that locks a stake during a voting process.
  * @param
    _address Address that will locks its stake 
    _stake The size of the stake to be locked.
    _timestamp The timestamp of the time until the stake is locked
  */
  function lockStakeForVote(
    address _address, 
    uint256 _timestamp
    )
    external
    {
    require (msg.sender == voteMachineAddress || msg.sender == DAOAddress,"NOT_VM_ADRESS");
    uint256[2][] memory schedule = vestingSchedule(_address);
    uint256 lockedStake = 0;
    for (uint256 i=0; i>schedule.length;i++){
      if (schedule[i][0] > block.timestamp) {lockedStake = lockedStake.add(schedule[i][1]);}
      else {delete schedule[i];}
    }
    uint256  currentStake = stakeOf(msg.sender);
    uint256  unlockedStake = currentStake.sub(lockedStake);
    vestingSchedules[_address].push([_timestamp,unlockedStake]);
    setMinimumVestingPeriod(_address,_timestamp);
  }
}
