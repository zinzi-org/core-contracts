const assert = require('assert');
const ganache = require('ganache-cli');
const Web3 = new require('web3');
const provider = ganache.provider();
const web3 = new Web3(provider);

const memberBoardFactoryCompiled = require('../build/MemberBoardFactory.json');
const memberBoardCompiled = require('../build/MemberBoard.json');
const memberNFTCompiled = require('../build/Member.json');
const projectFactoryCompiled = require('../build/ProjectFactory.json');
const projectCompiled = require('../build/Project.json');
const proposalNFTCompiled = require('../build/Proposal.json');

let accounts;

let memberBoardFactory;
let memberNFT;
let projectFactory;
let proposalNFT;


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

    projectFactory = await new web3.eth.Contract(projectFactoryCompiled.abi)
        .deploy({ data: projectFactoryCompiled.evm.bytecode.object })
        .send({ from: accounts[1], gas: '1000000' });

    proposalNFT = await new web3.eth.Contract(proposalNFTCompiled.abi)
        .deploy({ data: proposalNFTCompiled.evm.bytecode.object, arguments: [memberNFT.options.address] })
        .send({ from: accounts[1], gas: '3000000' });


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

    it('has project factory', async () => {
        assert.ok(projectFactory.options.address);
    });

    it('has proposal nft', async () => {
        assert.ok(proposalNFT.options.address);
    });

    it('can create member board', async () => {
        await memberBoardFactory.methods.create("Harvard University").send({ from: accounts[0], gas: 1000000 })
    });
});
