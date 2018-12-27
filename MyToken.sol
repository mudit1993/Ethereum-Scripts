pragma solidity ^0.4.21;

contract owned {
    
    address public owner;
    
    function owned() public{
        owner = msg.sender;
    }
    
    modifier onlyOwner(){
        require(owner == msg.sender);
        _;
    }
    
    function transferOwnership(address newOwner) onlyOwner public{
        owner = newOwner;
    }
    
}

contract MyToken316 is owned {
    
    bytes32 public currentChallenge;
    uint public difficulty = 10 ** 32;
    uint public timeOfLastProof;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 public buyPrice;
    uint256 public sellPrice;
    uint public minBalanceForAccount;
    
    
    mapping (address => uint256) public balanceOf; // array with all balances
    mapping(address => bool) public frozenAccount;
    mapping(address => bool) public approvedAccount;
    
    
    event Transfer(address indexfrom , address indexTo , uint256 value);
    event FrozenFunds(address target , bool freeze);
    event ApproveFunds(address target , bool approve);
    event Burn(address target , uint256 token);
    /*
     * Constructor 
     */
    function MyToken316(uint256 initialSupply,string tokenName,string tokenSymbol,uint8 decimalUnits, address centralMinter) public{
        if(centralMinter!=0) owner = centralMinter;
        if(initialSupply == 0) { balanceOf[msg.sender] = 100000;}
        totalSupply = initialSupply;
        balanceOf[msg.sender] = initialSupply; // creator has all initial tokens
        name= tokenName;
        symbol = tokenSymbol;
        decimals = decimalUnits;
        timeOfLastProof = now;
    }
    
    function setPrices(uint256 newBuyPrice , uint256 newSellPrice ) public {
        buyPrice = newBuyPrice;
        sellPrice = newSellPrice;
    }
    
    function setMinBalanceForAccount(uint minimumBalanceInFinney) public {
        minBalanceForAccount = minimumBalanceInFinney * 1 finney;
    }
    /**
     *  to transfer tokens between addresses
     */
    function transfer(address _to,uint256 value) public{
        //check for sufficient balance and overflow
        require(!frozenAccount[msg.sender]); // check if the account of the holder is frozen
        require(approvedAccount[msg.sender]);
        require(balanceOf[msg.sender]>= value &&  balanceOf[_to] + value >= balanceOf[_to]);
        if(_to.balance < minBalanceForAccount){
            _to.transfer(sell((minBalanceForAccount - _to.balance) / sellPrice));
        }
        uint initialState = balanceOf[msg.sender] + balanceOf[_to];
        balanceOf[msg.sender] -= value;
        balanceOf[_to] += value;
        require(balanceOf[msg.sender]+balanceOf[_to] == initialState);
        // To notify anyone listening that this transfer took place
        emit Transfer(msg.sender,_to,value);
        
    }
    
    function mintCoins(address target , uint256 mintedCoins) onlyOwner public{
        balanceOf[target] += mintedCoins;
        totalSupply += mintedCoins;
        emit Transfer(0,owner,mintedCoins);
        emit Transfer(owner,target,mintedCoins);
    }
    
    function burnCoins(uint256 coins) public returns(bool success){
        require(balanceOf[msg.sender] >= coins);
        balanceOf[msg.sender] -= coins;
        totalSupply -= coins;
        emit Burn(msg.sender,coins);
        return true;
    }
    
    function freezeAccount(address target , bool freeze) public
    {
        frozenAccount[target] = freeze;
        emit FrozenFunds(target,freeze);
    }
    
    function approveAccount(address target , bool approve) public{
        approvedAccount[target] = approve;
        emit ApproveFunds(target,approve);
    }
    
    function buy()  public payable returns(uint amount){
        amount = msg.value / buyPrice;
        require(balanceOf[this] >= amount);
        balanceOf[msg.sender] += amount;
        balanceOf[this] -= amount;
        emit Transfer(this,msg.sender,amount);
        return amount;
    }
    
    function sell(uint amount) public returns (uint revenue) {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -=amount;
        balanceOf[this] += amount;
        revenue = amount * sellPrice;
        msg.sender.transfer(revenue);
        emit Transfer(msg.sender,this,revenue);
        return revenue;
    }
    
    function proofOfWork(uint nonce) public {
        bytes8 x = bytes8(keccak256(nonce,currentChallenge));
        require(x >= bytes8(difficulty));
        uint timeSinceLastProof = now - timeOfLastProof;
        require(timeSinceLastProof >= 5 seconds);
        balanceOf[msg.sender] += (timeSinceLastProof / 60 seconds); // reward grows by a minute
        difficulty = difficulty * 10 minutes / timeSinceLastProof + 1; // adjusting difficulty
        timeOfLastProof = now;
        currentChallenge = keccak256(nonce,currentChallenge,block.blockhash(block.number - 1)); // save a hash that will be the next proof 
    }
}