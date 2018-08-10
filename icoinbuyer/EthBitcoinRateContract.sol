pragma solidity ^0.4.22;

//import "https://github.com/pipermerriam/ethereum-datetime/contracts/DateTime.sol";

contract ExtendUIntArray {
    uint256[] array;
    
    function get(uint256 index) public view returns(uint256) {
        return (array[index]);
    }
    
    function getLength() public view returns(uint256) {
        return (array.length);
    }
    
    function push(uint256 value) public {
        array.push(value);
    }
    
    function indexOf(uint256 value) public view returns(int) {
        int index = -1;
        for (uint i = 0; i < array.length; ++i) {
            if (array[i] == value) {
                index = int(i);
                break;
            }
        }
        return index;
    }
    
    function removeByValue(uint256 value) public {
        int index = indexOf(value);
        if (0 <= index) {
            remove(uint(index), 1);
        }
    }

    function remove(uint256 index, uint256 length) public {
        if (length == 0) return;
        if (array.length == 0) return;
        if (index + length > array.length) return;
        
        for (uint i = index; i < array.length - length; ++i) {
                array[i] = array[length + i];
        }
        for (uint j = array.length - length; j < array.length; ++j) {
            delete array[j];
        }
        array.length -= length;
    }
}

contract TradeRequestManager {
    enum TradeDirection {BUY, SALE}
    enum TradeRequestType {WAITING, DELAY}
    
    struct TradeRequest {
        uint256 requestNum;
        address customer;
        TradeDirection direction;
        uint256 requestCount;
    }
    
    uint256 nextRequestNumber;
    mapping(uint256 => TradeRequest) tradeRequestMapping;
    ExtendUIntArray buyRequestNumQueue;
    ExtendUIntArray saleRequestNumQueue;
    
    mapping(address => ExtendUIntArray) customerWaitingRequestNumMapping;
    mapping(address => ExtendUIntArray) customerDelayRequestNumMapping;
    
    constructor() public {
        buyRequestNumQueue = new ExtendUIntArray();
        saleRequestNumQueue = new ExtendUIntArray();
    }

    function matchRequest(address customer, uint256 requestCount, TradeDirection direction) 
        public returns (address[] successAddress, uint256[] successCount) {
        require(customer != address(0));
        require(0 != requestCount);
        
        ExtendUIntArray reverseList;
        if (direction == TradeDirection.BUY) {
            reverseList = saleRequestNumQueue;
        }
        if (direction == TradeDirection.SALE) {
            reverseList = buyRequestNumQueue;
        }

        uint256 successLength = 0;
        for (uint i = 0; i < reverseList.getLength(); ++i) {
            uint256 requestNum = reverseList.get(i);
            TradeRequest storage request = tradeRequestMapping[requestNum];
            
            if (request.customer == msg.sender) continue;
            
            successAddress[i] = request.customer;
            if (request.requestCount > requestCount) {
                request.requestCount -= requestCount;
                successCount[i] = requestCount;
                requestCount = 0;
            } else {
                successCount[i] = request.requestCount;
                requestCount -= request.requestCount;
                ++successLength;
                
                customerWaitingRequestNumMapping[request.customer].removeByValue(requestNum);
                delete tradeRequestMapping[requestNum];
            }
            if (0 == requestCount) break;
        }
        reverseList.remove(0, successLength);
        addTradeRequest(customer, requestCount, direction);
    }
    
    function addTradeRequest(address customer, uint256 requestCount, 
        TradeDirection direction) private {
        if (requestCount == 0) return;
        
        uint256 requestNum = generateNextRequestNumber();
        TradeRequest memory tradeRequest = TradeRequest(
                requestNum,
                msg.sender,
                direction,
                requestCount);
                
        if (TradeDirection.BUY == direction) {
            buyRequestNumQueue.push(requestNum);
        }
        if (TradeDirection.SALE == direction) {
            saleRequestNumQueue.push(requestNum);
        }
        tradeRequestMapping[requestNum] = tradeRequest;
        
        ExtendUIntArray customerList = customerWaitingRequestNumMapping[customer];
        if (customerList == address(0)) {
            customerList = new ExtendUIntArray();
            customerWaitingRequestNumMapping[customer] = customerList;
        }
        customerList.push(requestNum);
    }
    
    function getCustomerAllRequestWithType(address customer, TradeRequestType requestType) public 
        view returns(uint256[] customerRequestNumList, TradeDirection[] customerDirectionList, 
        uint256[] customerRequestCountList) {
        require(customer != address(0));
        
        ExtendUIntArray customerList;
        if (requestType == TradeRequestType.WAITING) {
            customerList = customerWaitingRequestNumMapping[customer];
        } 
        if (requestType == TradeRequestType.DELAY) {
            customerList = customerDelayRequestNumMapping[customer];
        }
        require(customerList != address(0));
        
        uint length = customerList.getLength();
        
        for (uint i = 0; i < length; ++i) {
            TradeRequest storage tradeRequest = tradeRequestMapping[customerList.get(i)];
            customerRequestNumList[i] = tradeRequest.requestNum;
            customerDirectionList[i] = tradeRequest.direction;
            customerRequestCountList[i] = tradeRequest.requestCount;
        }
    }
        //customer close waiting request
    function closeOneRequest(address customer, uint256 requestNum, 
        TradeRequestType requestType) public returns(uint256 requestCount, 
        TradeDirection direction) {
        require(0 != requestNum);
        require(customer != address(0));
        
        ExtendUIntArray customerList;
        if (requestType == TradeRequestType.WAITING) {
            customerList = customerWaitingRequestNumMapping[customer];
        } 
        if (requestType == TradeRequestType.DELAY) {
            customerList = customerDelayRequestNumMapping[customer];
        }
        
        require(customerList!= address(0));
        
        (requestCount, direction) = requestSetClose(customer, requestNum, requestType);
       
        customerList.removeByValue(requestNum);
    }
    
    function closeAllRequest(address customer, TradeRequestType requestType) 
        public returns(uint256[] requestCountArray, TradeDirection[] directionArray) {
        require(customer != address(0));
        
        ExtendUIntArray customerList;
        if (requestType == TradeRequestType.WAITING) {
            customerList = customerWaitingRequestNumMapping[customer];
        } 
        if (requestType == TradeRequestType.DELAY) {
            customerList = customerDelayRequestNumMapping[customer];
        } 
        require(customerList != address(0));
        
        for (uint256 i = 0; i < customerList.getLength(); ++i) {
            (requestCountArray[i], directionArray[i])= requestSetClose(customer, customerList.get(i), requestType);
        }
        delete customerWaitingRequestNumMapping[customer];
    }
    
    function requestSetClose(address customer, uint256 requestNum, 
        TradeRequestType requestType) private returns(uint256 requestCount, 
        TradeDirection direction) {
        TradeRequest storage tradeRequest = tradeRequestMapping[requestNum];
        require(tradeRequest.customer == customer);
        
        requestCount = tradeRequest.requestCount;
        direction = tradeRequest.direction;
        
        if (requestType == TradeRequestType.WAITING) {
            removeFromRequestQueue(tradeRequest.direction, requestNum);
        }
        delete tradeRequestMapping[requestNum];
    }
    
    function removeFromRequestQueue(TradeDirection direction, uint256 requestNum) private {
        if (direction == TradeDirection.BUY) {
            buyRequestNumQueue.removeByValue(requestNum);
        } 
        if (direction == TradeDirection.SALE) {
            saleRequestNumQueue.removeByValue(requestNum);
        }
    }
    
    function generateNextRequestNumber() private returns(uint256) {
        return (++nextRequestNumber);
    }
}

contract TradeOrderManager {
    
    struct TradeOrder {
        uint256 orderNum;
        uint256 index;
        address buyer;
        address seller;
        uint256 shareCount;     //份额
        uint256 buyWei;
        uint256 saleWei;
        bool buyerWithdraw;
        bool sellerWithdraw;
    }
    
    uint256 nextOrderNumber;
    
    ExtendUIntArray orderNumList;
    mapping(uint256 => TradeOrder) tradeOrderMapping;
    mapping(address => ExtendUIntArray) customerTradeOrderNumListMapping;
    
    constructor() public {
        orderNumList = new ExtendUIntArray();
    }
    
    function updateOrderPrice(bool raise, uint256 distancePrice) 
        public returns(address[] exploreAddressArray, uint256[] exploreWeiArray) {
        uint256 orderLength = orderNumList.getLength();
        if (orderLength == 0) return;
        
        uint256[] memory exploreOrderNumList = new uint256[](orderLength);
        for (uint i = 0; i < orderLength; ++i) {
            uint256 orderNum = orderNumList.get(i);
            TradeOrder storage tradeOrder = tradeOrderMapping[orderNum];
            if (0 == tradeOrder.orderNum) continue;
            
            uint256 distanceWei = distancePrice * tradeOrder.shareCount;
            
            if (raise) {
                if (tradeOrder.saleWei < distanceWei) {
                    distanceWei = tradeOrder.saleWei;
                }
                tradeOrder.saleWei -= distanceWei;
                tradeOrder.buyWei += distanceWei;
                if (tradeOrder.saleWei <= 0) {
                    exploreOrderNumList[i] = orderNum;
                    exploreAddressArray[i] = tradeOrder.buyer;
                    exploreWeiArray[i] = tradeOrder.buyWei;
                    
                    closeOneCustomerTradeOrderNum(tradeOrder.buyer, orderNum);
                    closeOneCustomerTradeOrderNum(tradeOrder.seller, orderNum);
                }
            } else {
                if (tradeOrder.buyWei < distanceWei) {
                    distanceWei = tradeOrder.buyWei;
                }
                tradeOrder.buyWei -= distanceWei;
                tradeOrder.saleWei += distanceWei;
                if (tradeOrder.buyWei <= 0) {
                    exploreOrderNumList[i] = orderNum;
                    exploreAddressArray[i] = tradeOrder.seller;
                    exploreWeiArray[i] = tradeOrder.saleWei;
                    
                    closeOneCustomerTradeOrderNum(tradeOrder.buyer, orderNum);
                    closeOneCustomerTradeOrderNum(tradeOrder.seller, orderNum);
                }
            }
        }
        for (uint256 j = 0; j < orderLength; ++j) {
            uint256 deleteOrderNum = exploreOrderNumList[j];
            if (deleteOrderNum == 0) continue;
            delete tradeOrderMapping[deleteOrderNum];
            orderNumList.removeByValue(deleteOrderNum);
        }
    }
    
    function push(address _buyer, address _seller, uint256 _shareCount, 
        uint256 _tradeUnit) public {
        
        uint256 orderNum = generateNextOrderNumber();
        orderNumList.push(orderNum);
        
        TradeOrder memory tradeOrder = TradeOrder(
            orderNum,
            orderNumList.getLength() - 1,
            _buyer,
            _seller,
            _shareCount,
            _shareCount * _tradeUnit,
            _shareCount * _tradeUnit,
            false,
            false);
        tradeOrderMapping[orderNum] = tradeOrder;
        
        pushToCustomer(orderNum, _buyer);
        pushToCustomer(orderNum, _seller);
    }
    
    function pushToCustomer(uint256 orderNum, address customer) public {
        ExtendUIntArray customerArray = customerTradeOrderNumListMapping[customer];
        if (customerArray == address(0)) {
            customerArray = new ExtendUIntArray();
            customerTradeOrderNumListMapping[customer] = customerArray;
        }
        customerArray.push(orderNum);
    }
    
    function getCustomerTradeOrder(address customer) public view returns(uint256[] customerOrderNumList, 
        uint256[] customerShareCountList, uint256[] customerWeiList) {
        require(customer != address(0));
        
        ExtendUIntArray tradeOrderNumList = customerTradeOrderNumListMapping[customer];
        require(tradeOrderNumList != address(0));
        
        for (uint i = 0; i < tradeOrderNumList.getLength(); ++i) {
            TradeOrder storage tradeOrder = tradeOrderMapping[tradeOrderNumList.get(i)];
            customerOrderNumList[i] = tradeOrder.orderNum;
            customerShareCountList[i] = tradeOrder.shareCount;
            if (customer == tradeOrder.buyer) {
                customerWeiList[i] = tradeOrder.buyWei;
            }  
            if (customer == tradeOrder.seller) {
                customerWeiList[i] = tradeOrder.saleWei;
            }
        }
    }
    
    function closeAllOrder(address customer) public returns(uint256 balance) {
        require(customer != address(0));
        
        ExtendUIntArray customerOrderNumList = customerTradeOrderNumListMapping[customer];
        require(customerOrderNumList != address(0));
        
        for (uint i = 0; i < customerOrderNumList.getLength(); ++i) {
            balance += orderSetClose(customer, customerOrderNumList.get(i));
        }
        delete customerTradeOrderNumListMapping[customer];
    }
    
    function closeOneOrder(address customer, uint256 orderNum) public returns(uint256 balance) {
        require(0 < orderNum);
        require(customer != address(0));
        
        balance = orderSetClose(customer, orderNum);
        closeOneCustomerTradeOrderNum(customer, orderNum);
    }
    
    function closeOneCustomerTradeOrderNum(address customer, uint256 orderNum) private {
        ExtendUIntArray customerTradeOrderNumList = customerTradeOrderNumListMapping[customer];
        customerTradeOrderNumList.removeByValue(orderNum);
        
        if (0 == customerTradeOrderNumList.getLength()) {
            delete customerTradeOrderNumListMapping[customer];
        }
    }
    
    function orderSetClose(address customer, uint256 orderNum) private returns(uint256 balance) {
        TradeOrder storage tradeOrder = tradeOrderMapping[orderNum];
        require(0 < tradeOrder.orderNum);
        
        if (tradeOrder.buyer == customer && !tradeOrder.buyerWithdraw) {
            tradeOrder.buyerWithdraw = true;
            balance = tradeOrder.buyWei;
        }
        
        if (tradeOrder.seller == customer && !tradeOrder.sellerWithdraw) {
            tradeOrder.sellerWithdraw = true;
            balance = tradeOrder.saleWei;
        }
        
        if (tradeOrder.buyerWithdraw && tradeOrder.sellerWithdraw) {
            orderNumList.remove(tradeOrder.index, 1);
            delete tradeOrderMapping[orderNum];
        }
    }
    
    function generateNextOrderNumber() private returns(uint256) {
        return (++nextOrderNumber);
    }
}

contract EthBitcoinTradeContract {
    
    event FallbackError(address addr, bytes data);
    
    uint256 public constant TRADE_UNIT = 10000000000000000;   //unit:wei, = 0.01 ethe
    
    uint8 public tradeStartHour;
    uint8 public tradeEndHour;
    
    address public adminAddress;
    address public benefitAddress;
    
    uint256 public updateTime;
    uint256 public currentPrice;
    
    TradeOrderManager tradeOrderManager;
    TradeRequestManager tradeRequestManager;
    
    mapping(address => uint256) customerWalletMapping;       //address => balance;
    
    constructor() public {
        adminAddress = msg.sender;
        benefitAddress = msg.sender;
        
        tradeOrderManager = new TradeOrderManager();
        tradeRequestManager = new TradeRequestManager();
    }
    
    function() public payable {
        emit FallbackError(msg.sender, msg.data);
    }
    
    modifier onlyAdmin() {
        require(msg.sender == adminAddress);
        _;
    }
    
    modifier tradeTime() {
        uint8 currentHour = getCurrentHour();
        require(tradeStartHour <= currentHour);
        require(tradeEndHour > currentHour);
        _;
    }
    
    function changeTradeTime(uint8 start, uint8 end) public onlyAdmin {
        require(end > start);
        require(end > 0);
        tradeStartHour = start;
        tradeEndHour = end;
    }
    
    function changeAdminAddress(address _addr) public onlyAdmin {
        require(_addr != address(0));
        adminAddress = _addr;
    }
    
    function changeBenefitAddress(address _addr) public onlyAdmin {
        require(_addr != address(0));
        benefitAddress = _addr;
    }
    
    function updatePrice(uint256 _price, uint256 _time) public onlyAdmin {
        updateTime = _time;
        if (_price == currentPrice) return;
        bool raise = _price > currentPrice;
        
        address[] memory addressArray;
        uint256[] memory weiArray;
        (addressArray, weiArray) = tradeOrderManager.updateOrderPrice(raise, 
            raise ? _price - currentPrice : currentPrice - _price);
        for (uint256 i = 0; i < weiArray.length; ++i) {
            addCustomerBalance(addressArray[i], weiArray[i]);
        }
        
    }
    
    function payWithTransfer(TradeRequestManager.TradeDirection direction) 
        public payable tradeTime {
        require(0 != msg.value);
        uint256 requestCount = msg.value / TRADE_UNIT;
        trade(requestCount, direction);
        
        addCustomerBalance(msg.sender, msg.value % TRADE_UNIT);
    }
    
    function payWithWallet(TradeRequestManager.TradeDirection direction, 
        uint256 requestCount) public tradeTime {
        require(requestCount * TRADE_UNIT <= customerWalletMapping[msg.sender]);
        customerWalletMapping[msg.sender] -= requestCount * TRADE_UNIT;
        trade(requestCount, direction);
    }
    
    function trade(uint256 requestCount, TradeRequestManager.TradeDirection direction) private {
        require(0 != requestCount);
        address[] memory addressArray;
        uint256[] memory successCountArray;
        
        (addressArray, successCountArray) = tradeRequestManager.matchRequest(msg.sender, 
            requestCount, TradeRequestManager.TradeDirection.SALE);
        
        for (uint256 i = 0; i < successCountArray.length; ++i) {
            uint256 successCount = successCountArray[i];
            if (successCount == 0) break;
            if (TradeRequestManager.TradeDirection.BUY == direction) {
                tradeOrderManager.push(msg.sender, addressArray[i], successCount, TRADE_UNIT);
            }
            if (TradeRequestManager.TradeDirection.SALE == direction) {
                tradeOrderManager.push(addressArray[i], msg.sender, successCount, TRADE_UNIT);
            }
        }
    }
    
    function closeOneOrder(uint256 orderNum) public tradeTime {
        addCustomerBalance(msg.sender, tradeOrderManager.closeOneOrder(msg.sender, orderNum));
    }
    
    function closeAllOrder() public tradeTime {
        addCustomerBalance(msg.sender, tradeOrderManager.closeAllOrder(msg.sender));
    }
    
    function closeOneRequest(uint256 requestNum, TradeRequestManager.TradeRequestType requestType) public tradeTime {
        uint256 requestCount;
        TradeRequestManager.TradeDirection direction;
        (requestCount, direction) = tradeRequestManager.closeOneRequest(msg.sender, 
            requestNum, requestType);
        addCustomerBalance(msg.sender, requestCount * TRADE_UNIT);
    }
    
    function closeAllRequest(TradeRequestManager.TradeRequestType requestType) public tradeTime {
        uint256[] memory requestCountArray;
        TradeRequestManager.TradeDirection[] memory directionArray;
        (requestCountArray, directionArray) = tradeRequestManager.closeAllRequest(msg.sender, 
            requestType);
        uint256 totalRequestCount;
        for (uint256 i = 0; i < requestCountArray.length; ++i) {
            totalRequestCount += requestCountArray[i];
        }
        addCustomerBalance(msg.sender, totalRequestCount * TRADE_UNIT);
    }
    
    function rewaitingOneTradeRequest(uint256 requestNum) public tradeTime {
        uint256 requestCount;
        TradeRequestManager.TradeDirection direction;
        (requestCount, direction) = tradeRequestManager.closeOneRequest(msg.sender,
            requestNum, TradeRequestManager.TradeRequestType.DELAY);
        trade(requestCount, direction);
    }
    
    function rewaitingAllTradeRequest() public tradeTime {
        uint256[] memory requestCountArray;
        TradeRequestManager.TradeDirection[] memory directionArray;
        (requestCountArray, directionArray) = tradeRequestManager.closeAllRequest(msg.sender, 
            TradeRequestManager.TradeRequestType.DELAY);
        for(uint i = 0; i < requestCountArray.length; ++i) {
            if (requestCountArray[i] == 0) break;
            trade(requestCountArray[i], directionArray[i]);
        }
    }
    
    function getCustomerAllRequestWithType(TradeRequestManager.TradeRequestType requestType) public 
        view returns(uint256[], TradeRequestManager.TradeDirection[], uint256[]) {
        return tradeRequestManager.getCustomerAllRequestWithType(msg.sender, requestType);       
    }
    
    function getCustomerAllTradeOrder() public view returns(uint256[], uint256[], uint256[]) {
        return tradeOrderManager.getCustomerTradeOrder(msg.sender);
    }

    function addCustomerBalance(address customer, uint256 balance) private {
        if (0 == balance || customer == address(0)) return;
        customerWalletMapping[customer] += balance;
    }

    //获取客户金额 
    function getCustomerBalance() public view returns(uint256) {
        return customerWalletMapping[msg.sender];
    }
    
    //客服提现
    function withdrawCuctomerBalance(uint256 balance) public {
        require(customerWalletMapping[msg.sender] >= balance);
        require(balance != 0);
        customerWalletMapping[msg.sender] -= balance;
        msg.sender.transfer(balance);
    }
    
    function getCurrentHour() private view returns(uint8) {
        return (uint8((now / 60 / 60) % 24) + 8) % 24;   //UTC/GMT+08:00
    }
}