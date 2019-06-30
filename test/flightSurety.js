
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var sharedFlight = `Flight ${Date.now()}`;
contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(operational) contract is operational`, async function () {

        // Get operating status
        let operational = await config.flightSuretyApp.isOperational();

        assert.equal(operational, true, "contract should be operational when deployed");

    });

    it(`(airline) contract is deployed with first airline registered`, async function () {

        // contract is deployed with the owner being registered as an airline but no funding
        let registeredTrue = await config.flightSuretyApp.isAirline(config.owner);
        let funding = await config.flightSuretyApp.fetchFunding(config.owner);
        let funded = await config.flightSuretyApp.isFunded(config.owner);

        assert.equal(registeredTrue, true, "first airline was not registered correctly");
        assert.equal(funding, 0, 'airline has some unwanted funding');
        assert.equal(funded, false, "airline status appears to be funded when it shouldnt ");

        let registeredFalse =  await config.flightSuretyApp.isAirline(accounts[2]);
        let registeredFalse2 =  await config.flightSuretyApp.isAirline(accounts[3]);
        let registeredFalse3 =  await config.flightSuretyApp.isAirline(accounts[4]);

        let numberOfRegistered = await config.flightSuretyApp.getNumberOfRegisteredAirlines();


        assert.equal(registeredFalse, false, "for some reason and unwanted airline was registered during deployment");
        assert.equal(registeredFalse2, false, "for some reason and unwanted airline was registered during deployment");
        assert.equal(registeredFalse3, false, "for some reason and unwanted airline was registered during deployment");

        assert.equal(numberOfRegistered, 0, "Registered airline counter was not increased");


    });


    it(`(airline) Registered airline can register a new airline`, async function () {

        // registered airline fails to adds a new airline to the registry due to lack of funding
        let successRegister = true;
        try{
            await config.flightSuretyApp.registerAirline(config.owner, {from: config.firstAirline});
        }
        catch (e) {
            successRegister = false
        }
        assert.equal(successRegister, false, "unfunded airline register another airline");
        let registerFalse = await config.flightSuretyApp.isAirline(config.firstAirline)
        assert.equal(registerFalse, false, "airline was not registered correctly")


        // now we fund the airline to be able to register a new one
        await config.flightSuretyApp.fund.sendTransaction(config.owner, {from: config.owner, value: 10});
        let isFundedTrue = await config.flightSuretyApp.isFunded(config.owner);
        let funding = await config.flightSuretyApp.fetchFunding(config.owner);
        let numberOfRegistered = await config.flightSuretyApp.getNumberOfRegisteredAirlines();

        assert.equal(funding.toString(), 10, "funding did not match what was expected");
        assert.equal(isFundedTrue, true, "Airline was not funded correctly");
        assert.equal(numberOfRegistered, 1, "There should now be a registered airline")

        await config.flightSuretyApp.registerAirline(config.firstAirline, {from: config.owner});
        let isAirlineTrue = await config.flightSuretyApp.isAirline(config.firstAirline)
        assert.equal(isAirlineTrue, true, "airline was not registered correctly")
    });


    it(`(airline) Not registered airline cannot register a new airline a new airline`, async function () {
        let success = true
        try{
            await config.flightSuretyApp.registerAirline(accounts[4], {from: accounts[3]});
        }
        catch (e) {
            success = false
        }

        // check that new airline is registered correctly
        let registeredFalse = await config.flightSuretyApp.isAirline(accounts[4]);
        let numberOfRegistered = await config.flightSuretyApp.getNumberOfRegisteredAirlines();

        assert.equal(success, false, "call was successful")
        assert.equal(registeredFalse, false, "first airline was not registered");
        assert.equal(numberOfRegistered, 1, "Registered airline counter was not increased");
    });



    it(`(multiparty) Up to 4 airlines can be registered without consensus`, async function () {

        let fifthAirline = accounts[5];
        // register second, third and 4th airline
        await config.flightSuretyApp.registerAirline(accounts[2], {from: config.owner});
        await config.flightSuretyApp.registerAirline(accounts[3], {from: config.owner});
        await config.flightSuretyApp.registerAirline(accounts[4], {from: config.owner});

        await config.flightSuretyApp.fund(accounts[2], {from: accounts[2], value:10});
        await config.flightSuretyApp.fund(accounts[3], {from: accounts[3], value:10});
        await config.flightSuretyApp.fund(accounts[4], {from: accounts[4], value:10});
        // airlines are now funded

        let numberOfRegistered1 = await config.flightSuretyApp.getNumberOfRegisteredAirlines();
        assert.equal(numberOfRegistered1, 4, "");

        // fifth airline should not be registered since we now need multyparty consensus
        await config.flightSuretyApp.registerAirline(fifthAirline);
        let isAirlineFalse = await config.flightSuretyApp.isAirline(fifthAirline, {from: config.firstAirline});
        assert.equal(isAirlineFalse, false, "5th airline was registered without multiparty consensus");

        // since the number of airlines is now 4, we need an extra vote to register the fifth airline
        await config.flightSuretyApp.registerAirline(fifthAirline, {from: accounts[2]});
        let isAirlineTrue = await config.flightSuretyApp.isAirline(fifthAirline);

        assert.equal(isAirlineTrue, true, "5th airline was not registered");
    });

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyApp.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });



    it(`(flight) passenger cannot buy more than 1 ether on surety for a flight`, async function () {

        let sharedFlight = "DummyFlight";
        let errored = false;

        try {
            await config.flightSuretyApp.buy.sendTransaction(accounts[9], sharedFlight, { from: accounts[9], value: 100000000000000000000000});
        }
        catch(e) {
            errored = true;
        }
        assert.equal(errored, true, "Passenger was able to buy more than 1 ETH in insurance");
    });

    it(`(flight) passenger can buy surety for a flight`, async function () {

        await config.flightSuretyApp.buy(accounts[9], sharedFlight, { from: accounts[9], value: 1000000000});
        let confirmation = await config.flightSuretyApp.flightSuretyInfo.call(sharedFlight, {from: accounts[9]});
        console.log(confirmation.toString());
        assert.equal(confirmation.toString(), 1000000000, "Surety was not purchased successfully");

    });


    it(`(flight) passenger can not buy twice surety for a flight`, async function () {
        // Get operating status
        let errored = false;
        try {
            await config.flightSuretyApp.buy.sendTransaction(accounts[9], sharedFlight, { from: accounts[9], value: 1000000000});
        }
        catch(e) {
            errored = true;
        }
        assert.equal(errored, true, "Passenger bought insurance twice");
    });

    it(`(flight) credits passenger 1.5 times the insured amount.`, async function () {
        // todo: this should only happen once a flight is delayed do to technical problems
        await config.flightSuretyApp.creditInsurees(accounts[9], sharedFlight);
        let confirmation = await config.flightSuretyApp.getPassengerCredit({from: accounts[9]});
        assert.equal(confirmation.toString(), 1000000000*1.5, "Surety was not purchased successfully");
    });

     it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try
        {
            await config.flightSuretyApp.setOperatingStatus(false, { from: accounts[9] });
        }
        catch(e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyApp.setOperatingStatus(false);
        let reverted = false;
        try
        {
            await config.flightSuretyApp.registerAirline(accounts[7]);
        }
        catch(e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for when contract is not operational");
        // Set it back for other tests to work
        await config.flightSuretyApp.setOperatingStatus(true);
    });

});
