// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GPUsMarketplace {
    AggregatorV3Interface internal ethUsdPriceFeed;
    uint256 constant SECONDS_PER_HOUR = 60 * 60;
    constructor() {
        ethUsdPriceFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
    }

    uint256 numberOfOrders;

    function getEthPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        require(price > 0, "Invalid ETH price.");
        return uint256(price / 10**8);
    }

     function addHours(uint256 timestamp, uint256 _hours) internal pure returns (uint256 newTimestamp) {
        newTimestamp = timestamp + _hours * SECONDS_PER_HOUR;
        require(newTimestamp >= timestamp);
    }

    struct Order {
        address provider;
        address consumer;
        uint256 noOfGPUs;
        uint256 endTime;
        uint256 NumberOfHours;
        bool returned;
    }

    struct GPUProvider {
        address providerAddress;
        string name;
        uint256 availableGPUs;
        uint256 gpuRate; //per hour in USD
    }

    struct GPUConsumer {
        address consumerAddress;
        string name;
    }

    event RentGPUs(
        address indexed consumer,
        address indexed provider,
        uint256 noofGPUs
    );

    mapping(address => GPUProvider) gpuProviders;
    mapping(address => GPUConsumer) gpuConsumers;
    mapping(string => address) providers;
    mapping(uint256 => Order) orders;
    string[] providerNames;

    function registerProvider(
        string memory _name,
        uint256 _availableGPUs,
        uint256 _gpuRate
    ) external {
        gpuProviders[msg.sender] = GPUProvider(
            msg.sender,
            _name,
            _availableGPUs,
            _gpuRate
        );
        providers[_name] = msg.sender;
        providerNames.push(_name);
    }

    function registerConsumer(string memory _name) external {
        gpuConsumers[msg.sender] = GPUConsumer(msg.sender, _name);
    }

    function isExpiry(uint256 _orderNumber) public payable {
        require(
            orders[_orderNumber].endTime < block.timestamp,
            "Time not expired"
        );
        if (!orders[_orderNumber].returned) {
            (bool success, ) = orders[_orderNumber].provider.call{
                value: 1 ether
            }("");
            require(success, "Transfer failed");
        }
    }

    function rentGPU(
        string memory _providerName,
        uint256 _noOFGPUs,
        uint256 _numberOfHours
    ) public payable returns (uint256) {
        require(myBalance(), "you has less than one ether");
        require(
            gpuProviders[providers[_providerName]].availableGPUs > _noOFGPUs,
            "Quantity of GPUs are less"
        );
        require(msg.value==1 ether,"Send one ether for rent");
        uint256 time = addHours(block.timestamp, _numberOfHours);
        orders[numberOfOrders] = Order(
            msg.sender,
            providers[_providerName],
            _noOFGPUs,
            time,
            _numberOfHours,
            false
        );
        gpuProviders[providers[_providerName]].availableGPUs -= _noOFGPUs;
        //payable(address(this)).transfer(1 ether);
        numberOfOrders += 1;
        emit RentGPUs(msg.sender, providers[_providerName], _noOFGPUs);
        return numberOfOrders - 1;
    }

    function returnGPUs(uint256 _orderNumber) external payable {
        uint256 payingAmount = 1 -
            ((gpuProviders[orders[_orderNumber].provider].gpuRate *
                orders[_orderNumber].NumberOfHours *
                orders[_orderNumber].noOfGPUs) / getEthPrice());
        (bool success, ) = orders[_orderNumber].provider.call{
            value: gpuProviders[orders[_orderNumber].provider].gpuRate *
                orders[_orderNumber].NumberOfHours *
                orders[_orderNumber].noOfGPUs*(10**18)
        }("");
        require(success, "Transfer failed");
        (success, ) = orders[_orderNumber].consumer.call{value: payingAmount*(10**18)}(
            ""
        );
        require(success, "Transfer failed");
        gpuProviders[orders[_orderNumber].provider].availableGPUs+=orders[_orderNumber].noOfGPUs;
        orders[_orderNumber].returned = true;
    }

    function getAllProviders() public view returns (string[] memory) {
        return providerNames;
    }

    function myBalance()internal view returns (bool) {
        return msg.sender.balance >= 1 ether;
    }

     receive() external payable {
        payable(address(this)).transfer(msg.value);
    }
}
