pragma solidity ^0.4.22;

//import "https://github.com/pipermerriam/ethereum-datetime/contracts/DateTime.sol";

contract ExtendUIntArray {
    uint256[] array;
    
    function get(uint256 index) public view returns(uint256) {
        return (array[index]);
    }
    
    function getAll() public view returns(uint256[]) {
        return array;
    }
    
    function getLength() public view returns(uint256) {
        return (array.length);
    }
    
    function push(uint256 value) public {
        array.push(value);
    }
    
    function pushAll(uint256[] _array) public {
        for (uint i = 0; i < _array.length; ++i) {
            push(_array[i]);
        }
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
    
    function clear() public {
        for (uint i = 0; i < array.length; ++i)  {
            delete array[i];
        }
        array.length = 0;
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
        public returns (address[], uint256[]) {
        require(customer != address(0));
        require(0 != requestCount);
        
        ExtendUIntArray reverseList;
        if (direction == TradeDirection.BUY) {
            reverseList = saleRequestNumQueue;
        }
        if (direction == TradeDirection.SALE) {
            reverseList = buyRequestNumQueue;
        }
        
        uint256 length = reverseList.getLength();
        
        address[] memory successAddress = new address[](length);
        uint256[] memory successCount = new uint256[](length);
        
        uint256 successLength = 0;
        for (uint i = 0; i < length; ++i) {
            uint256 requestNum = reverseList.get(i);
            TradeRequest storage request = tradeRequestMapping[requestNum];
            
            if (request.customer == customer) continue;
            
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
        
        return (successAddress, successCount);
    }
    
    function addTradeRequest(address customer, uint256 requestCount, 
        TradeDirection direction) private {
        if (requestCount == 0) return;
        
        uint256 requestNum = generateNextRequestNumber();
        TradeRequest memory tradeRequest = TradeRequest(
                requestNum,
                customer,
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
    
    function pullWaitingToDelay() public {
        
        pullWaitingToDelay(buyRequestNumQueue.getAll());
        buyRequestNumQueue.clear();
        
        pullWaitingToDelay(saleRequestNumQueue.getAll());
        saleRequestNumQueue.clear();
    }
    
    function pullWaitingToDelay(uint256[] requestNumArray) private {
         for (uint256 i = 0; i < requestNumArray.length; ++i) {
            TradeRequest storage tradeRequest = tradeRequestMapping[requestNumArray[i]];
            
            ExtendUIntArray waitingNumArray = customerWaitingRequestNumMapping[tradeRequest.customer];
            if (waitingNumArray == address(0)) continue;
            
            ExtendUIntArray delayNumArray = customerDelayRequestNumMapping[tradeRequest.customer];
            
            if (delayNumArray == address(0)) {
                customerDelayRequestNumMapping[tradeRequest.customer] = waitingNumArray;
            } else {
                delayNumArray.pushAll(waitingNumArray.getAll());
                customerDelayRequestNumMapping[tradeRequest.customer] = delayNumArray;
            }
            delete customerWaitingRequestNumMapping[tradeRequest.customer];
        }
    }
    
    function getCustomerAllRequestWithType(address customer, TradeRequestType requestType) public 
        view returns(uint256[], TradeDirection[] , uint256[]) {
        
        ExtendUIntArray customerList;
        if (requestType == TradeRequestType.WAITING) {
            customerList = customerWaitingRequestNumMapping[customer];
        } 
        if (requestType == TradeRequestType.DELAY) {
            customerList = customerDelayRequestNumMapping[customer];
        }
        require(customerList != address(0));
        
        uint256 length = customerList.getLength();
        
        uint256[] memory customerRequestNumList = new uint256[](length);
        TradeDirection[] memory customerDirectionList = new TradeDirection[](length); 
        uint256[] memory customerRequestCountList = new uint256[](length);
        
        for (uint i = 0; i < length; ++i) {
            TradeRequest storage tradeRequest = tradeRequestMapping[customerList.get(i)];
            customerRequestNumList[i] = tradeRequest.requestNum;
            customerDirectionList[i] = tradeRequest.direction;
            customerRequestCountList[i] = tradeRequest.requestCount;
        }
        return (customerRequestNumList, customerDirectionList, customerRequestCountList);
    }
        //customer close waiting request
    function closeOneRequest(address customer, uint256 requestNum, 
        TradeRequestType requestType) public returns(uint256, TradeDirection) {
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
        
        uint256 requestCount;
        TradeDirection direction;
        (requestCount, direction) = requestSetClose(customer, requestNum, requestType);
       
        customerList.removeByValue(requestNum);
        
        return (requestCount, direction);
    }
    
    function closeAllRequest(address customer, TradeRequestType requestType) 
        public returns(uint256[], TradeDirection[]) {
        require(customer != address(0));
        
        ExtendUIntArray customerList;
        if (requestType == TradeRequestType.WAITING) {
            customerList = customerWaitingRequestNumMapping[customer];
        } 
        if (requestType == TradeRequestType.DELAY) {
            customerList = customerDelayRequestNumMapping[customer];
        } 
        require(customerList != address(0));
        
        uint256 length = customerList.getLength();
        uint256[] memory requestCountArray = new uint256[](length); 
        TradeDirection[] memory directionArray = new TradeDirection[](length);
        for (uint256 i = 0; i < length; ++i) {
            (requestCountArray[i], directionArray[i])= requestSetClose(customer, customerList.get(i), requestType);
        }
        delete customerWaitingRequestNumMapping[customer];
        return (requestCountArray, directionArray);
    }
    
    function requestSetClose(address customer, uint256 requestNum, 
        TradeRequestType requestType) private returns(uint256, TradeDirection) {
        TradeRequest storage tradeRequest = tradeRequestMapping[requestNum];
        require(tradeRequest.customer == customer);
        
        uint256 requestCount = tradeRequest.requestCount;
        TradeDirection direction = tradeRequest.direction;
        
        if (requestType == TradeRequestType.WAITING) {
            removeFromRequestQueue(tradeRequest.direction, requestNum);
        }
        delete tradeRequestMapping[requestNum];
        return (requestCount, direction);
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
    
    function getCustomerTradeOrder(address customer) public view returns(uint256[], uint256[], uint256[]) {
        
        ExtendUIntArray tradeOrderNumList = customerTradeOrderNumListMapping[customer];
        require(tradeOrderNumList != address(0));
        
        uint256 length = tradeOrderNumList.getLength();
        uint256[] memory customerOrderNumList = new uint256[](length);
        uint256[] memory customerShareCountList = new uint256[](length);
        uint256[] memory customerWeiList = new uint256[](length);
        
        for (uint i = 0; i < length; ++i) {
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
        return (customerOrderNumList, customerShareCountList, customerWeiList);
    }
    
    function closeAllOrder(address customer) public returns(uint256, uint256[]) {
        require(customer != address(0));
        
        ExtendUIntArray customerOrderNumList = customerTradeOrderNumListMapping[customer];
        require(customerOrderNumList != address(0));
        
        uint256 length = customerOrderNumList.getLength();
        uint256 balance = 0;
        uint256[] memory orderNumArray = new uint256[](length);
        
        for (uint i = 0; i < length; ++i) {
            uint256 orderNum = customerOrderNumList.get(i);
            orderNumArray[i] = orderNum;
            balance += orderSetClose(customer, orderNum);
        }
        delete customerTradeOrderNumListMapping[customer];
        return (balance, orderNumArray);
    }
    
    function closeOneOrder(address customer, uint256 orderNum) public returns(uint256, uint256) {
        require(0 < orderNum);
        require(customer != address(0));
        
        uint256 balance = 0;
        balance = orderSetClose(customer, orderNum);
        closeOneCustomerTradeOrderNum(customer, orderNum);
        return (balance, orderNum);
    }
    
    function closeOneCustomerTradeOrderNum(address customer, uint256 orderNum) private {
        ExtendUIntArray customerTradeOrderNumList = customerTradeOrderNumListMapping[customer];
        customerTradeOrderNumList.removeByValue(orderNum);
        
        if (0 == customerTradeOrderNumList.getLength()) {
            delete customerTradeOrderNumListMapping[customer];
        }
    }
    
    function orderSetClose(address customer, uint256 orderNum) private returns(uint256) {
        TradeOrder storage tradeOrder = tradeOrderMapping[orderNum];
        require(0 < tradeOrder.orderNum);
        
        uint256 balance;
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
        return balance;
    }
    
    function generateNextOrderNumber() private returns(uint256) {
        return (++nextOrderNumber);
    }
}


contract EthBitcoinTradeContract {
    
    event CloseOneOrder(address addr, uint256 orderNum);
    event FallbackError(address addr, bytes data);
    event TradeCallback(uint256 requestCount, uint256 orderCount);
    event CloseAllOrder(address addr, uint256[] orderNumArray);
    
    uint256 public constant TRADE_UNIT = 10000000000000000;   //unit:wei, = 0.01 ethe
    
    uint8 public constant TRADE_START_HOUR = 9;
    uint8 public constant TRADE_END_HOUR = 4;
    
    address public adminAddress;
    address public benefitAddress;
    
    uint256 public updateTime;
    uint256 public oldPrice;
    uint256 public newPrice;
    
    uint256 public auctionCount;
    uint256 public buyCount;
    uint256 public sellCount;
    
    TradeOrderManager tradeOrderManager;
    TradeRequestManager tradeRequestManager;
    
    mapping(address => uint256) customerWalletMapping;       //address => balance;
    
    constructor() public {
        adminAddress = msg.sender;
        benefitAddress = msg.sender;
        
        tradeOrderManager = new TradeOrderManager();
        tradeRequestManager = new TradeRequestManager();
        
        // customerWalletMapping[msg.sender] = 1000000000000000000;
        // address addr = address(0x14723a09acff6d2a60dcdf7aa4aff308fddc160c);
        // customerWalletMapping[addr] = 2000000000000000000;
    }
    
    function() public payable {
        emit FallbackError(msg.sender, msg.data);
        revert();
    }
    
    modifier onlyAdmin() {
        require(msg.sender == adminAddress);
        _;
    }
    
    modifier tradeTime() {
        uint8 currentHour = getCurrentHour();
        require(TRADE_START_HOUR <= currentHour || TRADE_END_HOUR > currentHour);
        _;
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
        require(_price != 0);
        updateTime = _time;
        newPrice = _price;
        
        if (oldPrice == 0) {
            oldPrice = _price;
        }
    }
    
    function confirmPrice() public onlyAdmin {
        require(oldPrice != newPrice);
        require(newPrice != 0);
        require(oldPrice != 0);
        
        bool raise = newPrice > oldPrice;
        
        address[] memory addressArray;
        uint256[] memory weiArray;
        (addressArray, weiArray) = tradeOrderManager.updateOrderPrice(raise, 
            raise ? newPrice - oldPrice : oldPrice - newPrice);
        for (uint256 i = 0; i < weiArray.length; ++i) {
            uint256 explodeWei = weiArray[i];
            if (explodeWei == 0) continue;
            addCloseOrderBalance(addressArray[i], explodeWei);
        }
        
        tradeRequestManager.pullWaitingToDelay();
        
        oldPrice = newPrice;
        newPrice = 0;
        auctionCount = 0;
        buyCount = 0;
        sellCount = 0;
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
    
    event TradeResult(address[] addressArray, uint256[] successCountArray);
    
    function trade(uint256 requestCount, TradeRequestManager.TradeDirection direction) private {
        require(0 != requestCount);

        if (TradeRequestManager.TradeDirection.BUY == direction) {
            buyCount += requestCount;
        }
        if (TradeRequestManager.TradeDirection.SALE == direction) {
            sellCount += requestCount;
        }
        
        address[] memory addressArray;
        uint256[] memory successCountArray;
        
        (addressArray, successCountArray) = tradeRequestManager.matchRequest(msg.sender, 
            requestCount, direction);
            
        uint256 totalSuccessCount = 0;
        for (uint256 i = 0; i < successCountArray.length; ++i) {
            uint256 successCount = successCountArray[i];
            if (successCount == 0) break;
            if (TradeRequestManager.TradeDirection.BUY == direction) {
                tradeOrderManager.push(msg.sender, addressArray[i], successCount, TRADE_UNIT);
            }
            if (TradeRequestManager.TradeDirection.SALE == direction) {
                tradeOrderManager.push(addressArray[i], msg.sender, successCount, TRADE_UNIT);
            }
            totalSuccessCount += successCount;

        }
        auctionCount += totalSuccessCount;
        emit TradeCallback(requestCount - totalSuccessCount, totalSuccessCount);
    }
    
    function closeOneOrder(uint256 orderNum) public tradeTime {
        uint256 balance;
        uint256 _orderNum;
        (balance, _orderNum) = tradeOrderManager.closeOneOrder(msg.sender, orderNum);
        addCloseOrderBalance(msg.sender, balance);
        emit CloseOneOrder(msg.sender, _orderNum);
    }
    
    function closeAllOrder() public tradeTime {
        uint256 balance;
        uint256[] memory orderNumArray;
        (balance, orderNumArray) = tradeOrderManager.closeAllOrder(msg.sender);
        addCloseOrderBalance(msg.sender, balance);
        emit CloseAllOrder(msg.sender, orderNumArray);
    }
    
    function addCloseOrderBalance(address customer, uint256 balance) private {
        uint256 benefitWei = balance / 1000 / 2;
        addCustomerBalance(benefitAddress, benefitWei);
        addCustomerBalance(customer, balance - benefitWei);
    }
    
    function closeOneRequest(uint256 requestNum, TradeRequestManager.TradeRequestType requestType) public tradeTime {
        uint256 requestCount;
        TradeRequestManager.TradeDirection direction;
        (requestCount, direction) = tradeRequestManager.closeOneRequest(msg.sender, 
            requestNum, requestType);
        addCustomerBalance(msg.sender, requestCount * TRADE_UNIT);
        
        cutRequestCount(requestCount, direction);
    }
    
    function closeAllRequest(TradeRequestManager.TradeRequestType requestType) public tradeTime {
        uint256[] memory requestCountArray;
        TradeRequestManager.TradeDirection[] memory directionArray;
        (requestCountArray, directionArray) = tradeRequestManager.closeAllRequest(msg.sender, 
            requestType);
        uint256 totalRequestCount;
        for (uint256 i = 0; i < requestCountArray.length; ++i) {
            uint256 requestCount = requestCountArray[i];
            totalRequestCount += requestCount;
            
            cutRequestCount(requestCount, directionArray[i]);
        }
        addCustomerBalance(msg.sender, totalRequestCount * TRADE_UNIT);
    }
    
    function cutRequestCount(uint256 requestCount, TradeRequestManager.TradeDirection direction) public {
        if (TradeRequestManager.TradeDirection.BUY == direction) {
            buyCount -= requestCount;
        }
        if (TradeRequestManager.TradeDirection.SALE == direction) {
            sellCount -= requestCount;
        }
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
    
    function getCurrentHour() public view returns(uint8) {
        return (uint8((now / 60 / 60) % 24) + 8) % 24;   //UTC/GMT+08:00
    }
    
}