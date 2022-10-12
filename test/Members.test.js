const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = new require('web3');
const provider = ganache.provider();
const web3 = new Web3(provider);

const memberBoardFactoryCompiled = require('../build/MemberBoardFactory.json');
const memberBoardCompiled = require('../build/MemberBoard.json');
const memberNFTCompiled = require('../build/Member.json');


let accounts;

let memberBoardFactory;
let memberNFT;




async function baseFullSetup() {
    accounts = await web3.eth.getAccounts();

    memberBoardFactory = await new web3.eth.Contract(memberBoardFactoryCompiled.abi)
        .deploy({ data: memberBoardFactoryCompiled.evm.bytecode.object })
        .send({ from: accounts[1], gas: '5000000' });

    var memberNFTAdress = await memberBoardFactory.methods.memberNFTAddress().call();

    memberNFT = await new web3.eth.Contract(
        memberNFTCompiled.abi,
        memberNFTAdress
    );





}

describe("Base Test Setup", () => {

    before(async () => {
        await baseFullSetup();
    });

    it('has test accounts available', () => {
        assert.ok(accounts.length > 0);
    });

    it('has member board factory', async () => {
        assert.ok(memberBoardFactory.options.address);
    });

    it('has member nft', async () => {
        assert.ok(memberNFT.options.address);
    });


    it('can create member board', async () => {
        await memberBoardFactory.methods.create("Harvard University").send({ from: accounts[0], gas: 1000000 })
    });
});
