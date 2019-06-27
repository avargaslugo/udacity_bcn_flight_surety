var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
var sharedFlight = `Flight ${Date.now()}`;
contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        //await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
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
        let registeredTrue = await config.flightSuretyApp.isAirline(config.firstAirline);
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
            await config.flightSuretyApp.registerAirline(config.firstAirline, {from: config.owner});
        }
        catch (e) {
            successRegister = false
        }
        assert.equal(successRegister, false, "unfunded airline register another airline");

        await config.flightSuretyApp.fund.sendTransaction(config.firstAirline, {from: config.firstAirline, value: 10});
        let isFundedTrue = await config.flightSuretyApp.isFunded(config.firstAirline);
        let funding = await config.flightSuretyApp.fetchFunding(config.firstAirline);
        let numberOfRegistered = await config.flightSuretyApp.getNumberOfRegisteredAirlines();
        assert.equal(funding.toString(), 10, "funding did not match what was expected");
        assert.equal(isFundedTrue, true, "Airline was not funded correctly");
        assert.equal(numberOfRegistered, 1, "There should now be a registered airline")

    });


    it(`(airline) Not registered airline cannot register a new airline a new airline`, async function () {

        try{
            await config.flightSuretyApp.registerAirline(accounts[4], {from: accounts[3]});
        }
        catch (e) {
        }

        // check that new airline is registered correctly
        let registeredFalse = await config.flightSuretyApp.isAirline(accounts[4]);
        let numberOfRegistered = await config.flightSuretyApp.getNumberOfRegisteredAirlines();

        assert.equal(registeredFalse, false, "first airline was not registered");
        assert.equal(numberOfRegistered, 1, "Registered airline counter was not increased");
    });



    it(`(multiparty) Up to 4 airlines can be registered without consensus`, async function () {

        let fifthAirline = accounts[5];
        // register second, third and 4th airline
        await config.flightSuretyApp.registerAirline(accounts[2], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(accounts[3], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(accounts[4], {from: config.firstAirline});

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



});
