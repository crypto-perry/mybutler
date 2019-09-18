pragma solidity >=0.5.0;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC20Dummy is IERC20 {

    string public constant name = "ERC20DummyToken";
    string public constant symbol = "DUMMY_TOKEN";

    constructor() public {}  

    function totalSupply() public view returns (uint256) {
	    return 0;
    }
    
    function balanceOf(address tokenOwner) public view returns (uint) {
        return 0;
    }

    function transfer(address receiver, uint numTokens) public returns (bool) {
        revert();
    }

    function approve(address delegate, uint numTokens) public returns (bool) {
        revert();
    }

    function allowance(address owner, address delegate) public view returns (uint) {
        return 0;
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
        revert();
    }
}

contract ERC20Test is IERC20 {
    using SafeMath for uint256;
    string public constant name = "ERC20TestToken";
    string public constant symbol = "TEST_TOKEN";

    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);

    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;
    uint256 totalSupply_;

    constructor(uint256 total) public {  
    	totalSupply_ = total;
    	balances[msg.sender] = totalSupply_;
    }  

    function totalSupply() public view returns (uint256) {
	    return totalSupply_;
    }
    
    function balanceOf(address tokenOwner) public view returns (uint) {
        return balances[tokenOwner];
    }

    function transfer(address receiver, uint numTokens) public returns (bool) {
        require(numTokens <= balances[msg.sender]);
        balances[msg.sender] -= numTokens;
        balances[receiver] = balances[receiver].add(numTokens);
        emit Transfer(msg.sender, receiver, numTokens);
        return true;
    }

    function approve(address delegate, uint numTokens) public returns (bool) {
        allowed[msg.sender][delegate] = numTokens;
        emit Approval(msg.sender, delegate, numTokens);
        return true;
    }

    function allowance(address owner, address delegate) public view returns (uint) {
        return allowed[owner][delegate];
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
        require(numTokens <= balances[owner]);    
        require(numTokens <= allowed[owner][msg.sender]);
    
        balances[owner] -= numTokens;
        allowed[owner][msg.sender] -= numTokens;
        balances[buyer] = balances[buyer].add(numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }
}

library SafeMath { 
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a + b;
      assert(c >= a);
      return c;
    }
}