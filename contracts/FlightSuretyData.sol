pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Ownable.sol";

contract FlightSuretyData is Ownable {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address[] multiCalls = new address[](0);
    uint8 AIRLINE_LENGTH_LIMIT = 5;
    //bool isAirlineRegistrationOperational = true;

    address private contractOwner;                                      // Account used to deploy contract
    address[] enabledAirlines = new address[](0);

    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    struct Airline {
        bool isRegistered;      // Flag for testing existence in mapping
        uint256 funding;
        bool isFunded;
    }

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        string id;
    }

    // mapping of callers that are authorized to call the contract
    mapping(address => uint8) authorizedCaller;
    // mapping from airline addresses to their details
    mapping(address => Airline) airlines;   // All registered airlines
    // mapping from flight numbers as strings to flight details
    mapping(string => Flight) flights;
    // available funds for passangers to widrawl
    mapping(address => uint256) credits;
    //mapping(address => uint256) funds;
    mapping(bytes32 => uint256) flightSurety;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AuthorizedCaller(address caller);
    event DeAuthorizedCaller(address caller);
    event CreditInsured(address passenger, string flight, uint256 amount);

    event RegisterAirline   // Event fired when a new Airline is registered
    (
        address indexed account     // "indexed" keyword indicates that the data should be
    // stored as a "topic" in event log data. This makes it
    // searchable by event log filters. A maximum of three
    // parameters may use the indexed keyword per event.
    );

    event RegisterFlight   // Event fired when a new Airline is registered
    (
        string indexed account     // "indexed" keyword indicates that the data should be
    // stored as a "topic" in event log data. This makes it
    // searchable by event log filters. A maximum of three
    // parameters may use the indexed keyword per event.
    );


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() public
    {
        contractOwner = msg.sender;
        //adds first airline upon its constructor
        airlines[contractOwner] = Airline({
            isRegistered: true,
            //account: contractOwner,
            //ownership: 0,
            funding: 0,
            isFunded: false
        });
        emit RegisterAirline(contractOwner);   // Log airline registration event
    }


    modifier requireIsCallerAuthorized()
    {
        require(authorizedCaller[msg.sender] == 1, "Caller is not authorized to call this function");
        _;
    }


    modifier requireIsOperational()
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }


    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireRegisteredAirline(address caller){
        require(airlines[caller].isRegistered, "Caller is not registered");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /* authorize caller */
    function authorizeCaller(address _caller) public onlyOwner returns(bool)
    {
        authorizedCaller[_caller] = 1;
        emit AuthorizedCaller(_caller);
        return true;
    }


    /* deauthorize caller */
    function deAuthorizeCaller(address _caller) public onlyOwner returns(bool)
    {
        authorizedCaller[_caller] = 0;
        emit DeAuthorizedCaller(_caller);
        return true;
    }


    function setOperatingStatus(bool mode, address sender) external requireContractOwner
    {
        require(mode != operational, "New mode must be different from existing mode");

        bool isDuplicate = false;
        for(uint c=0; c<multiCalls.length; c++) {
            if (multiCalls[c] == sender) {
                isDuplicate = true;
                break;
            }
        }

        require(!isDuplicate, "Caller has already called this function.");

        multiCalls.push(sender);
        if (multiCalls.length >= (enabledAirlines.length.div(2))) {
            operational = mode;
            multiCalls = new address[](0);
        }
    }

    function isOperational() external view returns(bool)
    {
        return operational;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function registerAirline(address airline, address registeringAirline) external requireIsCallerAuthorized requireIsOperational
    {
        // airline cannot be registered twice
        require(!airlines[airline].isRegistered, "Airline already registered");
        // only registered airlines can register other airlines
        require(airlines[registeringAirline].isRegistered, "Airline trying to add no exists");

        require(airlines[registeringAirline].isFunded, "Airlines need to be funded to be able register other airlines");
        // up to the forth airline can be added without multiparty consensus
        if (enabledAirlines.length < 4){
            airlines[airline] = Airline({isRegistered: true, funding: 0, isFunded: false});
        }
        // else consensus is needed
        else {
            // check if registeringAirline airline has not voted already
            bool isDuplicate = false;
            for(uint c=0; c<multiCalls.length; c++) {
                if (multiCalls[c] == registeringAirline) {
                    isDuplicate = true;
                    break;
                    }
                }

            require(!isDuplicate, "Caller has already voted");
            // add registeringAirline to the list of airlines that have already voted.
            multiCalls.push(registeringAirline);
            // if half of the airlines have voted, the new airline is accepted
            if (multiCalls.length == (enabledAirlines.length.div(2))) {
                // new airline is registered without funding
                airlines[airline] = Airline({isRegistered: true, funding: 0, isFunded: false});
                // the voters array is reset
                multiCalls = new address[](0);
                //emit RegisterAirline(airline);   // Log airline registration event
            }
        }
    }

    function registerFlight(address airline, string flightId, uint256 timestamp) external
    requireIsCallerAuthorized
    requireIsOperational
    {
        require(airlines[airline].isRegistered, "Airline does not exists");
        flights[flightId] = Flight({
            isRegistered: true,
            statusCode: 0,
            updatedTimestamp: timestamp,
            airline: airline,
            id: flightId
        });

        emit RegisterFlight(flightId);   // Log airline registration event
    }


    function isAirline(address airline) external view requireIsCallerAuthorized requireIsOperational returns(bool)
    {
        return airlines[airline].isRegistered;
    }


    function getActiveAirlines() external view requireIsCallerAuthorized requireIsOperational returns(address[])
    {
        return enabledAirlines;
    }

    // method for buying insurance
    function buy(address passenger, string flight) external payable requireIsOperational
    {
        // it's not possible to buy insurance for more tha 1 ETH
        require(msg.value <= 1 ether, "Surety value cannot be higher than 1 ether");
        // get's hash of passenger and flight
        bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        require(flightSurety[key] == 0, "Passenger already bought surety on this flight");
        flightSurety[key] = msg.value;
    }

    // returns the amount of insurance bought by passenger for flight
    function flightSuretyInfo(address passenger, string flight) external requireIsCallerAuthorized requireIsOperational returns(uint256)
    {
        bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        // require(flightSurety[key] > 0, "Passenger does not have surety for this flight");
        return flightSurety[key];
    }

    // function crediting passengers indirectly. credit does not go directly to their walled
    function creditPassenger(address passenger, string flight) external payable requireIsCallerAuthorized
    requireIsOperational
    {
        // get hash for passenger and flight
        bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        // get insured amount
        uint256 insuredAmount = flightSurety[key];
        require(insuredAmount > 0, "No insurance was purchased by this passenger for this flight");
        //Requirement #2
        // calculate amount to credit from the insurance bought
        uint256 amountToCredit = insuredAmount.mul(15).div(10);
        uint256 currentCredit = credits[passenger];
        // adds the amount to credit to the passenger existing credit.
        credits[passenger] = currentCredit.add(amountToCredit);
        emit CreditInsured(passenger, flight, amountToCredit);
    }

    function withdraw(address passenger, uint256 amount) external requireIsCallerAuthorized
    requireIsOperational
    {
        // get credits for passenger
        uint256 credit = credits[passenger];
        // requires there should be some credit
        require(credit > 0, "There is no credits to withdraw");
        // transfer credit to passenger
        passenger.transfer(credit);
        // after withdrawl credits for passenger is reset to 0
        credits[passenger] = 0;
    }


    function fund(address airline) public payable requireIsCallerAuthorized requireIsOperational
    {
        require(msg.value >= 10, "Minimum amount is 10");
        require(airlines[airline].isRegistered, "Airline not registered");

        uint256 currentAmount = airlines[airline].funding;
        airline.transfer(msg.value);

        // if airline has not been funded yet
        if (!airlines[airline].isFunded) {
            // declares it as funded
            airlines[airline].isFunded = true;
            // adds it to the list of airlines that can participate in the contract
            enabledAirlines.push(airline);
        }
        airlines[airline].funding = currentAmount.add(msg.value);
    }

    function fetchFunding(address airline) external view requireIsOperational requireIsCallerAuthorized returns (uint256){
        return airlines[airline].funding;
    }

    function isFunded(address airline) external view requireIsOperational requireIsCallerAuthorized returns (bool){
        return airlines[airline].isFunded;
    }

    function getNumberOfRegisteredAirlines() requireIsOperational requireIsCallerAuthorized external view returns (uint256) {
        return enabledAirlines.length;
    }

    function getPassengerCredit(address passenger) requireIsOperational requireIsCallerAuthorized external view
    returns (uint256){
        return credits[passenger];
    }

    /**
       * @dev Fallback function for funding smart contract.
       *
       */
    function()
    external
    payable
    requireIsCallerAuthorized
    requireIsOperational
    {
        fund(msg.sender);
    }

}

