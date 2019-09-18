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

contract ERC20Swap {
    using SafeMath for uint256;
    
    enum TradeState {None, SellPaid, BuyPaid}
 
    event OpenTrade(address indexed buyer, address indexed seller, address token, uint256 ethAmount, uint256 tokenAmount, uint256 expiration, TradeState state);
    event CloseTrade(address indexed buyer, address indexed seller, uint256 tradeId);

    address public owner;
    uint256 public feesGathered;

    mapping (uint256 => TradeState) public trades;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }
    
    function trade(bool wantToBuy, address payable other, address token, uint256 tokenAmount, uint256 ethAmount, uint256 expiration) public payable {
        require(ethAmount > 100000);
        uint256 tradeId = wantToBuy 
                        ? uint256(keccak256(abi.encodePacked(msg.sender, other, token, ethAmount, tokenAmount, expiration)))
                        : uint256(keccak256(abi.encodePacked(other, msg.sender, token, ethAmount, tokenAmount, expiration)));
        TradeState state = trades[tradeId];
        if (state == TradeState.None) { // If trade doesn't exist
            if (wantToBuy) { // If trying to buy
                require(msg.value == ethAmount.add(computeFee(ethAmount))); // Take eth and fee from buyer
                trades[tradeId] = TradeState.BuyPaid; // Update state
                emit OpenTrade(msg.sender, other, token, ethAmount, tokenAmount, expiration, TradeState.BuyPaid); // Log open BUY
            } else { // If trying to sell
                require(IERC20(token).transferFrom(msg.sender, address(this), tokenAmount)); // Take tokens from seller
                trades[tradeId] = TradeState.SellPaid; // Update state
                emit OpenTrade(other, msg.sender, token, ethAmount, tokenAmount, expiration, TradeState.SellPaid); // Log open SELL
            }
        } else if (wantToBuy && state == TradeState.SellPaid) { // If buyer closes the trade
            require(expiration > now);
            uint256 fee = computeFee(ethAmount);
            require(msg.value == ethAmount.add(fee)); // Take eth and fee from buyer
            trades[tradeId] = TradeState.None; // Close trade first to protect against reentrancy
            require(IERC20(token).transfer(msg.sender, tokenAmount)); // Send tokens to buyer (from this contract as seller already paid us)
            other.transfer(ethAmount - fee); // Send eth - fee to seller
            feesGathered = feesGathered.add(fee).add(fee);
            emit CloseTrade(msg.sender, other, tradeId);
        } else if (!wantToBuy && state == TradeState.BuyPaid) { // If seller closes the trade
            require(expiration > now);
            trades[tradeId] = TradeState.None; // Close trade first to protect against reentrancy
            require(IERC20(token).transferFrom(msg.sender, other, tokenAmount)); // Send tokens to buyer (directly from seller)
            uint256 fee = computeFee(ethAmount);
            msg.sender.transfer(ethAmount - fee); // Send eth - fee to seller
            feesGathered = feesGathered.add(fee).add(fee);
            emit CloseTrade(other, msg.sender, tradeId);
        } else {
            revert();
        }
    }
    
    function cancelTrade(bool wantToBuy, address payable other, address token, uint256 tokenAmount, uint256 ethAmount, uint256 expiration) public {
        uint256 tradeId = wantToBuy 
                        ? uint256(keccak256(abi.encodePacked(msg.sender, other, token, ethAmount, tokenAmount, expiration)))
                        : uint256(keccak256(abi.encodePacked(other, msg.sender, token, ethAmount, tokenAmount, expiration)));
        TradeState state = trades[tradeId];
        if (wantToBuy && state == TradeState.BuyPaid) { // If buyer cancels the trade
            trades[tradeId] = TradeState.None; // Close trade first to protect against reentrancy
            msg.sender.transfer(ethAmount + computeFee(ethAmount)); // Refund eth + fee to buyer
            emit CloseTrade(msg.sender, other, tradeId);
        } else if (!wantToBuy && state == TradeState.SellPaid) { // If seller cancels the trade
            trades[tradeId] = TradeState.None; // Close trade first to protect against reentrancy
            require(IERC20(token).transfer(msg.sender, tokenAmount)); // Refund tokens to seller
            emit CloseTrade(other, msg.sender, tradeId);
        } else {
            revert();
        }
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
    
    function tradeInfo(bool wantToBuy, address payable other, address token, uint256 tokenAmount, uint256 ethAmount, uint256 expiration) public view 
    returns (uint256 _tradeId, uint256 _buySideTotal, TradeState) {
        _buySideTotal = ethAmount.add(computeFee(ethAmount));

        address payable buyer; address payable seller; (buyer, seller) = wantToBuy ? (msg.sender, other) : (other, msg.sender);
        
        _tradeId = uint256(keccak256(abi.encodePacked(buyer, seller, token, ethAmount, tokenAmount, expiration)));
        return (_tradeId, _buySideTotal, trades[_tradeId]);
    }
    
    function() external payable {
        revert();
    }
}
