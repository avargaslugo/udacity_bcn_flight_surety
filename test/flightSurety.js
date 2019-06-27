
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



    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyApp.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try
        {
            await config.flightSuretyApp.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch(e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try
        {
            await config.flightSuretyApp.setOperatingStatus(false, {"from": accounts[2]});
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
            await config.flightSuretyApp.setTestingMode(true);
        }
        catch(e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyApp.setOperatingStatus(true);
    });


    it(`(flight) passenger can buy more than 1 ether on surety for a flight`, async function () {

        let sharedFlight = "DummyFlight";
        // Get operating status

        let errored = false;

        try {
            await config.flightSuretyApp.buy.sendTransaction(accounts[9], sharedFlight, { from: accounts[9], value: 100000000000000000000000});
        }
        catch(e) {
            errored = true;
        }

        assert.equal(errored, true, "Surety value has not changed");
    });



    it(`(flight) passenger can buy surety for a flight`, async function () {

        // Get operating status

        config.flightSuretyApp.buy.sendTransaction(accounts[9], sharedFlight, { from: accounts[9], value: 1000000000});


        let confirmation = await config.flightSuretyApp.flightSuretyInfo.call(sharedFlight, {"from": accounts[9]});
        console.log(confirmation.toString());
        assert.equal(confirmation, 1000000000, "Surety was not purchased successfully");

    });

    it(`(flight) passenger can not buy twice a surety for a flight`, async function () {
        // Get operating status

        let errored = false;
        try {
            await config.flightSuretyApp.buy.sendTransaction(accounts[9], sharedFlight, { from: accounts[9], value: 1000000000});
        }
        catch(e) {
            errored = true;
        }

        assert.equal(errored, true, "Surety value has not changed");

    });


});
