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

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a);
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b);
        return c;
    }
}

contract ERC20OpenBuy {
    using SafeMath for uint256;
    
    event UpdateBuy(address maker, address token, uint256 ethPerToken, uint256 expiration, uint256 amountRemaining);

    address public owner;
    uint256 public feesGathered;

    mapping (uint256 => uint256) public trades;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }
    
    function addToBuyOffer(address token, uint256 ethPerToken, uint256 expiration) public payable {
        uint256 tradeId = uint256(keccak256(abi.encodePacked(msg.sender, token, ethPerToken, expiration)));
        trades[tradeId] = trades[tradeId].add(msg.value.mul(1000) / 1005);
        emit UpdateBuy(msg.sender, token, ethPerToken, expiration, trades[tradeId]); // Log open BUY
    }
    
    function partialFillBuy(address token, uint256 ethPerToken, uint256 expiration, uint256 tokenAmount, address payable other) public {
        uint256 tradeId = uint256(keccak256(abi.encodePacked(other, token, ethPerToken, expiration)));
        uint256 ethPayment = tokenAmount.mul(ethPerToken);
        require(trades[tradeId] >= ethPayment); // Make sure there is enough ether to pay for these tokens
        trades[tradeId] = trades[tradeId] - ethPayment;
        require(IERC20(token).transferFrom(msg.sender, other, tokenAmount)); // Take tokens from seller and give to buyer
        uint256 fee = computeFee(ethPayment);
        msg.sender.transfer(ethPayment - fee);
        feesGathered = feesGathered.add(fee).add(fee);
        emit UpdateBuy(other, token, ethPerToken, expiration, trades[tradeId]); // Log open BUY
    }
    
    function cancelBuyOffer(address token, uint256 ethPerToken, uint256 expiration) public {
        uint256 tradeId = uint256(keccak256(abi.encodePacked(msg.sender, token, ethPerToken, expiration)));
        uint256 ethAmount = trades[tradeId];
        trades[tradeId] = 0;
        msg.sender.transfer(ethAmount + computeFee(ethAmount)); // Refund eth + fee to buyer
        emit UpdateBuy(msg.sender, token, ethPerToken, expiration, 0); // Log open BUY
    }
    
    function _withdrawFees() public onlyOwner {
        uint256 amount = feesGathered;
        feesGathered = 0;
        msg.sender.transfer(amount);
    }
    
    function computeFee(uint256 value) private pure returns (uint256) {
        return value.mul(5) / 1000; // this is the fee we take on each side (0.5%)
    }
    
    function getExpirationAfter(uint256 amountOfHours) public view returns (uint256) {
        return now + (amountOfHours * (1 hours));
    }
    
    function tradeInfo(address payable other, address token, uint256 ethPerToken, uint256 expiration, uint256 tokenAmount) public view 
    returns (uint256 _tradeId, uint256 _buySideTotal, uint256 _amountRemaining) {
        _buySideTotal = tokenAmount.mul(ethPerToken);
        _buySideTotal = _buySideTotal.add(computeFee(_buySideTotal));
        address payable maker = other == address(0x0) ? msg.sender : other;
        _tradeId = uint256(keccak256(abi.encodePacked(maker, token, ethPerToken, expiration)));
        return (_tradeId, _buySideTotal, trades[_tradeId]);
    }
    
    function() external payable {
        revert();
    }
}


contract ERC20OpenSell {
    using SafeMath for uint256;
    
    event UpdateSell(address maker, address token, uint256 ethPerToken, uint256 expiration, uint256 amountRemaining);

    address public owner;
    uint256 public feesGathered;

    mapping (uint256 => uint256) public trades;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }
    
    function addToSellOffer(address token, uint256 ethPerToken, uint256 expiration, uint256 tokenAmount) public {
        uint256 tradeId = uint256(keccak256(abi.encodePacked(msg.sender, token, ethPerToken, expiration)));
        require(IERC20(token).transferFrom(msg.sender, address(this), tokenAmount)); // Take tokens from seller
        trades[tradeId] = trades[tradeId].add(tokenAmount); // Update state
        emit UpdateSell(msg.sender, token, ethPerToken, expiration, trades[tradeId]); // Log open SELL
    }
    
    function partialFillSell(address token, uint256 ethPerToken, uint256 expiration, address payable other) public payable {
        uint256 tradeId = uint256(keccak256(abi.encodePacked(other, token, ethPerToken, expiration)));
        uint256 ethPayment = msg.value.mul(1000) / 1005; // Without fee
        uint256 tokenAmount = ethPayment / ethPerToken;
        require(trades[tradeId] >= tokenAmount); // Make sure there are enough tokens to pay
        trades[tradeId] = trades[tradeId] - tokenAmount; // Update state
        require(IERC20(token).transfer(msg.sender, tokenAmount)); // Give tokens to buyer
        uint256 fee = computeFee(ethPayment);
        other.transfer(ethPayment - fee); // Pay the seller
        feesGathered = feesGathered.add(fee).add(fee);
        emit UpdateSell(other, token, ethPerToken, expiration, trades[tradeId]); // Log open BUY
    }
    
    function cancelSellOffer(address token, uint256 ethPerToken, uint256 expiration) public {
        uint256 tradeId = uint256(keccak256(abi.encodePacked(msg.sender, token, ethPerToken, expiration)));
        uint256 tokenAmount = trades[tradeId];
        trades[tradeId] = 0;
        IERC20(token).transfer(msg.sender, tokenAmount); // Refund seller
        emit UpdateSell(msg.sender, token, ethPerToken, expiration, 0); // Log open SELL
    }
    
    function _withdrawFees() public onlyOwner {
        uint256 amount = feesGathered;
        feesGathered = 0;
        msg.sender.transfer(amount);
    }
    
    function computeFee(uint256 value) private pure returns (uint256) {
        return value.mul(5) / 1000; // this is the fee we take on each side (0.5%)
    }
    
    function getExpirationAfter(uint256 amountOfHours) public view returns (uint256) {
        return now + (amountOfHours * (1 hours));
    }
    
    function tradeInfo(address payable other, address token, uint256 ethPerToken, uint256 expiration, uint256 tokenAmount) public view 
    returns (uint256 _tradeId, uint256 _buySideTotal, uint256 _amountRemaining) {
        _buySideTotal = tokenAmount.mul(ethPerToken);
        _buySideTotal = _buySideTotal.add(computeFee(_buySideTotal));
        address payable maker = other == address(0x0) ? msg.sender : other;
        _tradeId = uint256(keccak256(abi.encodePacked(maker, token, ethPerToken, expiration)));
        return (_tradeId, _buySideTotal, trades[_tradeId]);
    }
    
    function() external payable {
        revert();
    }
}
