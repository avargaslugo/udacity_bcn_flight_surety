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
    bool isAirlineRegistrationOperational = true;

    address private contractOwner;                                      // Account used to deploy contract
    // In Solidity, all mappings always exist. "isRegistered" is a flag that can only be
    // "true" if it was set in code, so it's a good way to query items for mapping types.
    address[] enabledAirlines = new address[](0);

    bool private has_initialized = false;
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    bool private testingMode = false;

    struct Airline {
        bool isRegistered;      // Flag for testing existence in mapping
        //address account;        // Ethereum account
        //uint256 ownership;      // Track percentage of Smart Contract ownership based on initial contribution
        uint256 funding;
        bool isFunded;
    }

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        string id;
        bool hasBeenInsured;
    }

    mapping(address => uint8) authorizedCaller;
    mapping(address => Airline) airlines;   // All registered airlines
    mapping(string => Flight) flights;
    mapping(string => address[]) flightInsurees;
    mapping(address => uint256) funds;
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

    /**
* @dev Modifier that requires the "operational" boolean variable to be "true"
*      This is used on all state changing functions to pause the contract in
*      the event there is an issue that needs to be fixed
*/
    modifier requireIsOperational()
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
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

    /**
   * @dev Sets contract operations on/off
   *
   * When operational mode is disabled, all write transactions except for this one will fail
   */
    function setOperatingStatus
    (
        bool mode,
        address sender
    )
    external
    {
        require(mode != operational, "New mode must be different from existing mode");
        require(airlines[sender].isRegistered, "Caller is not an registered");

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

    /**
     * @dev Sets testing mode on/off
     *
     * When testing mode is enabled, certain functions will behave differently (example: skip time-based delays)
     * @return A bool that is the new testing mode
     */
    function setTestingMode
    (
        bool mode
    )
    external
    requireContractOwner
    requireIsOperational
    {
        testingMode = mode;
    }


    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
    external
    view
    returns(bool)
    {
        return operational;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
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
   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerFlight
    (
        address airline,
        string flightId,
        uint256 timestamp
    )
    external
    requireIsCallerAuthorized
    requireIsOperational
    {

        require(airlines[airline].isRegistered, "Airline does not exists");
        flights[flightId] = Flight({
            isRegistered: true,
            statusCode: 0,
            updatedTimestamp: timestamp,
            airline: airline,
            id: flightId,
            hasBeenInsured: false
        });

        emit RegisterFlight(flightId);   // Log airline registration event
    }

    /**
      * @dev Query if the airliner is already registered
      *
      * @return A bool that indicated
    */
    function isAirline(
        address airline
    )
    external
    view
    requireIsCallerAuthorized
    requireIsOperational
    returns(bool)
    {
        return airlines[airline].isRegistered;
    }

    /**
     * @dev Get all active airlines
     *
     * @return Airline addresses array
    */
    function getActiveAirlines(
    )
    external
    view
    requireIsCallerAuthorized
    requireIsOperational
    returns(address[])
    {
        return enabledAirlines;
    }

    /**
      * @dev Retrieve airline ownership setting
      *
      * @return Airline ownership
     */
    //function getAirlineOwnership(address airline) external view requireIsCallerAuthorized requireIsOperational returns(uint256)
    //{
      //  return airlines[airline].ownership;
    //}

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy
                            (
                                address passenger,
                                string flight
                            )
                            external
                            payable
                            requireIsOperational
    {

        require(msg.value <= 1 ether, "Surety value cannot be higher than 1 ether");
        bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        require(!flights[flight].hasBeenInsured, "Surety has already been paid for this flight");
        require(flightSurety[key] <= 0, "Passenger already bought surety on this flight");
        flightSurety[key] = msg.value;
//        flightInsurees[flight].push(passenger);
    }

    /**
     * @dev Get flightSurety info
     *
     */
    function flightSuretyInfo
                            (
                                address passenger,
                                string flight
                            )
                            external
                            requireIsCallerAuthorized
                            requireIsOperational
                            returns(uint256)
    {

        bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        require(flightSurety[key] > 0, "Passenger does not have surety for this flight");
        return flightSurety[key];
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                address passenger,
                                string flight
                                )
                                external
                                payable
                                requireIsCallerAuthorized
                                requireIsOperational
    {


        bytes32 key = keccak256(abi.encodePacked(passenger, flight));
        uint256 currentFund = flightSurety[key];
        require(currentFund > 0, "There is no value to refund");
        //Requirement #2
        uint256 amountToCredit = currentFund.mul(15).div(10);
        flightSurety[key] = amountToCredit;
        emit CreditInsured(passenger, flight, amountToCredit);

        //The snippet and validations below are regarding a fully functional app, considerating that all the flights are registered and not mocked up
        // This will refund only the caller and will not control if it was not already funded or not

//        require(flights[flight].isRegistered, "Flight does not exist");
//        require(!flights[flight].hasBeenInsured, "Surety has already been paid for this flight");

        //        address[] passengers = flights[flight].passengers;
//        for (uint i = 0; i < passengers.length; i ++) {
//            bytes32 key = keccak256(abi.encodePacked(passengers[i], flight));
//            uint256 currentFund = flightSurety[key];
//            uint256 creditRate = currentFund.div(2);
//            uint256 amountToCredit = currentFund.add(creditRate);
//            flightSurety[key] = amountToCredit;
//            emit CreditInsured(passengers[i], flight, amountToCredit);
//        }


    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    //Requirement #3
    function withdraw
                            (
                            string flight,
                            uint256 amount
                            )
                            external
                            requireIsCallerAuthorized
                            requireIsOperational
    {

        bytes32 key = keccak256(abi.encodePacked(msg.sender, flight));
        uint256 value = flightSurety[key];

        require(value >= amount, "There is no sufficient value to withdraw");

        flightSurety[key] = 0;
        msg.sender.transfer(amount);
        flightSurety[key] = value.sub(amount);
    }


    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
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

