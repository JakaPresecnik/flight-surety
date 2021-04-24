pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                                  // Account used to deploy contract
    bool private operational = true;                                                // Blocks all state changes throughout the contract if false
    mapping (address => Airline) public airlines;                                   // Data storage for all airlines
    mapping (uint => mapping (address => uint)) public flightPassengers;            // Data storage for passengers in a flight
    
    struct Airline {                                                                // Struct for creating an airline, with info
        string name;
        address airlineID;
        bool registered;
        bool funded;
        uint256 fundedAmount;
    }
    
    // Using mapping with variables to avoid arrays
    uint128 private registeredAirlines = 0;                                         // an integer that tracks the amount of registered airlines
    mapping (address => mapping (address => bool)) private registerAirlineWaitlist; // mapping that stores confirmed addresses for an airline
    uint64 private registersConfirmed = 0;                                          // an integer to count the addresses that confirmed the airline to register
    

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event AirlineRegistered(address airlineID);
    event AirlineQueued(address airlineID);
    event InsuranceBought(uint amount);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor()  public  {
        contractOwner = msg.sender;
        airlines[msg.sender] = Airline('Initialized Airlines', msg.sender, true, true, 0);
        registeredAirlines += 1;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }
    
    /**
     * Modifier that requires registred airlines to be the function caller
     **/
    modifier requireRegisteredAirline() {
        require(airlines[msg.sender].registered, "Caller is not a registered airline");
        _;
    }
    
    /**
     * Modifier that resticts actions for airlines that didn't funded the contract
     **/
     modifier requireFundedAirline() {
         require(airlines[msg.sender].funded, "Caller hasn't funded the contract with 10 ether");
         _;
     }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() public view returns(bool) {
        return operational;
    }

    /**
     * Used for testing: Check if airline is registered
     **/
     function isAirline(address _airline) public view returns(bool) {
         return airlines[_airline].registered;
     }
     
     function getPassenger(address _passengerID, uint _flightID) public view returns (uint) {
         return flightPassengers[_flightID][_passengerID];
     }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus (bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
    
    /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    */   
    function registerAirline(address _airline, string _name) external requireIsOperational requireRegisteredAirline requireFundedAirline {
        if (registeredAirlines < 4) {
            airlines[_airline] = Airline(_name, _airline, true, false, 0);
            registeredAirlines += 1;
            
            emit AirlineRegistered(_airline);
        } else {
           require(!registerAirlineWaitlist[_airline][msg.sender], "Caller already approved");
           registerAirlineWaitlist[_airline][msg.sender] = true;
           registersConfirmed += 1;
           
           emit AirlineQueued(_airline);
           
           if(registersConfirmed >= registeredAirlines / 2) {
                airlines[_airline] = Airline(_name, _airline, true, false, 0);
                registeredAirlines += 1;
                registersConfirmed = 0;
                
                emit AirlineRegistered(_airline);
           }
        }
    }

    /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy (uint _flightID) external payable requireIsOperational{
        require(flightPassengers[_flightID][msg.sender] == 0, "Caller already bought the insurance");
        require(msg.value > 0, "Caller didn't send any amount");
        require(msg.value <= 1 ether, "Caller's amount was above the limit");
        
        contractOwner.transfer(msg.value);
        flightPassengers[_flightID][msg.sender] = msg.value;
        
        emit InsuranceBought(msg.value);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees() external pure {

    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay () external pure {

    }

    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund () public payable requireIsOperational requireRegisteredAirline {
        airlines[msg.sender].fundedAmount.add(msg.value);
        contractOwner.transfer(msg.value);

        if(airlines[msg.sender].fundedAmount >= 10000000000000000000) {
            airlines[msg.sender].funded = true;
        }
    }

    function getFlightKey (address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32)  {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external  payable  {
        fund();
    }


}