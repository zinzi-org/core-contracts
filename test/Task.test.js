const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, should } = require("chai");
const { ethers } = require("hardhat");


describe("Task Test Cases", () => {

    async function taskFixture() {

        const [...signers] = await ethers.getSigners();

        const boardFactoryFactory = await ethers.getContractFactory("GovernorBoardFactory");
        const factoryContract = await boardFactoryFactory.deploy();
        var membersAddress = await factoryContract.membersAddress();

        const projectTokenFactory = await ethers.getContractFactory("ProjectToken");
        let projectTokenContract = await projectTokenFactory.deploy();
        projectTokenContract = projectTokenContract.connect(signers[0]);

        const taskFactory = await ethers.getContractFactory("Task");
        let taskContract = await taskFactory.deploy(membersAddress, projectTokenContract.address);

        const membersFactory = await ethers.getContractFactory("Members");
        let membersContract = membersFactory.attach(membersAddress);
        membersContract = membersContract.connect(signers[0]);

        await factoryContract.create("ZinziDAO", "ZZ");

        var usersTokens = await membersContract.getBoards(signers[0].address);
        var boardAddress = await membersContract.getBoardForToken(usersTokens[0]);

        const boardFactory = await ethers.getContractFactory("GovernorBoard");
        let boardContract = boardFactory.attach(boardAddress);
        boardContract = boardContract.connect(signers[0]);

        const memberVotesAddress = boardContract.getMemberVotesAddress();
        const memberVotesFactory = await ethers.getContractFactory("MemberVote");
        let memberVotesContract = memberVotesFactory.attach(memberVotesAddress);
        memberVotesContract = memberVotesContract.connect(signers[0]);

        for (var i = 1; i < signers.length; i++) {
            await boardContract.addMember(signers[i].address);
        }

        return { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers };
    }


    it("can create a task and accept a proposal", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers } = await loadFixture(taskFixture);

        var propTx = await taskContract.createProject(
            "Run Advertising Campaign",
            "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore"
            , { gasLimit: 1000000, value: 10000000 }
        );
        const rcMint = await propTx.wait();
        const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
        const [projectTokenId] = eventMint.args;

        var balance = await taskContract.getTotalBalance();

        expect(balance).to.equal(10000000);

        let taskContractInst = taskContract.connect(signers[1]);


        var tokenId = await membersContract.getTokenId(signers[1].address);

        var proposalTx = await taskContractInst.createProposal(
            tokenId,
            projectTokenId,
            "I will do this because im smart",
            8000,
            { gasLimit: 1000000 }
        );
        const rc = await proposalTx.wait();
        const event = rc.events.find(event => event.event === 'Proposal');
        const [proposalId] = event.args;

        var proposalDetails = await taskContractInst.getProposalDetails(projectTokenId, proposalId);

        var projectDetailsInitial = await taskContract.getProjectDetails(projectTokenId);
        expect(projectDetailsInitial.amountFunded).to.equal(10000000);

        var proposalHash = await taskContractInst.generateProposalHash("I will do this because im smart", projectTokenId, tokenId);

        expect(proposalDetails.proposalHash).to.equal(proposalHash);

        let approveTx = await taskContract.populateTransaction.ownerApproveProposal(projectTokenId, proposalId);
        gasEstimate = await ethers.provider.estimateGas(approveTx);
        approveTx.gasLimit = gasEstimate;
        let txResponse = await signers[0].sendTransaction(approveTx);
        await txResponse.wait();

        var state = await taskContract.projectState(projectTokenId);
        expect(state).to.equal(0);

        let propCreatorApproveTx = await taskContractInst.populateTransaction.approveProposal(projectTokenId, proposalId);
        gasEstimate = await ethers.provider.estimateGas(propCreatorApproveTx);
        propCreatorApproveTx.gasLimit = gasEstimate;
        let propCreatorTxResponse = await signers[1].sendTransaction(propCreatorApproveTx);
        await propCreatorTxResponse.wait();

        var stateApproved = await taskContract.projectState(projectTokenId);

        expect(stateApproved).to.equal(1);

    });

    it("can create a proposal and update the project hash", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers } = await loadFixture(taskFixture);

        var propTx = await taskContract.createProject(
            "Run Advertising Campaign",
            "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore"
            , { gasLimit: 1000000, value: 10000000 }
        );
        const rcMint = await propTx.wait();
        const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
        const [projectTokenId] = eventMint.args;

        var projectDetailsInitial = await taskContract.getProjectDetails(projectTokenId);

        var updateHashTx = await taskContract.populateTransaction.updateProjectHash(
            projectTokenId,
            "Run digital advertising campaign",
            "I need someone to run a digital adveritising campaign with pictures of my dog. I want to target people who like dogs and live in Baltimore");
        gasEstimate = await ethers.provider.estimateGas(updateHashTx);
        updateHashTx.gasLimit = gasEstimate;
        let updateResponse = await signers[0].sendTransaction(updateHashTx);
        await updateResponse.wait();

        var projectDetail = await taskContract.getProjectDetails(projectTokenId);

        expect(projectDetail.projectHash).to.not.equal(projectDetailsInitial.projectHash);

    });

    it("can create a proposal and insert more funding", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers } = await loadFixture(taskFixture);

        var propTx = await taskContract.createProject(
            "Run Advertising Campaign",
            "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore"
            , { gasLimit: 1000000, value: 10000000 }
        );
        const rcMint = await propTx.wait();
        const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
        const [projectTokenId] = eventMint.args;

        var projectDetailsInitial = await taskContract.getProjectDetails(projectTokenId);

        var projectHash = await taskContract.generateProjectHash("Run Advertising Campaign", "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore");

        expect(projectDetailsInitial.projectHash).to.equal(projectHash);

        var updateHashTx = await taskContract.populateTransaction.increaseProjectFunding(
            projectTokenId, {value: 10000000}
            );
        gasEstimate = await ethers.provider.estimateGas(updateHashTx);
        updateHashTx.gasLimit = gasEstimate;
        let updateResponse = await signers[0].sendTransaction(updateHashTx);
        await updateResponse.wait();

        var projectDetailsInitial = await taskContract.getProjectDetails(projectTokenId);
        expect(projectDetailsInitial.amountFunded).to.equal(20000000);

    });

    it("can create a proposal for a task and update the proposal", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers } = await loadFixture(taskFixture);
        var propTx = await taskContract.createProject(
            "Run Advertising Campaign",
            "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore"
            , { gasLimit: 1000000, value: 10000000 }
        );
        const rcMint = await propTx.wait();
        const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
        const [projectTokenId] = eventMint.args;

        let taskContractInst = taskContract.connect(signers[1]);

        var tokenId = await membersContract.getTokenId(signers[1].address);

        var proposalTx = await taskContractInst.createProposal(
            tokenId,
            projectTokenId,
            "I will do this because im smart",
            8000,
            { gasLimit: 1000000 }
        );
        const rc = await proposalTx.wait();
        const event = rc.events.find(event => event.event === 'Proposal');
        const [proposalId] = event.args;

        var proposalDetailsInitial = await taskContract.getProposalDetails(projectTokenId, proposalId);


        var updateHashTx = await taskContractInst.populateTransaction.updateProposal(
                projectTokenId,
                proposalId,
                "I will do this because im kinda of smart",
                8000
            );

        gasEstimate = await ethers.provider.estimateGas(updateHashTx);
        updateHashTx.gasLimit = gasEstimate;
        let updateResponse = await signers[1].sendTransaction(updateHashTx);
        await updateResponse.wait();

        var proposalDetails = await taskContract.getProposalDetails(projectTokenId, proposalId);

        expect(proposalDetails.proposalHash).to.not.equal(proposalDetailsInitial.proposalHash);



    });
        

    it("can create a proposal for a task and then cancel the proposal", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers } = await loadFixture(taskFixture);
        var propTx = await taskContract.createProject(
            "Run Advertising Campaign",
            "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore"
            , { gasLimit: 1000000, value: 10000000 }
        );
        const rcMint = await propTx.wait();
        const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
        const [projectTokenId] = eventMint.args;

        let taskContractInst = taskContract.connect(signers[1]);

        var tokenId = await membersContract.getTokenId(signers[1].address);

        var proposalTx = await taskContractInst.createProposal(
            tokenId,
            projectTokenId,
            "I will do this because im smart",
            8000,
            { gasLimit: 1000000 }
        );
        const rc = await proposalTx.wait();
        const event = rc.events.find(event => event.event === 'Proposal');
        const [proposalId] = event.args;

        var proposalDetailsInitial = await taskContract.getProposalDetails(projectTokenId, proposalId);

        expect(proposalDetailsInitial.proposalState).to.equal(0);

        var cancelProposalTx = await taskContractInst.populateTransaction.cancelProposal(
            projectTokenId,
            proposalId
        );

        gasEstimate = await ethers.provider.estimateGas(cancelProposalTx);
        cancelProposalTx.gasLimit = gasEstimate;
        let cancelResponse = await signers[1].sendTransaction(cancelProposalTx);
        await cancelResponse.wait();

        var proposalDetails = await taskContract.getProposalDetails(projectTokenId, proposalId);


        expect(proposalDetails.proposalState).to.equal(3);



    });

    //completeProposal
    it("can create a proposal for a task and then complete the proposal", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers } = await loadFixture(taskFixture);

        var propTx = await taskContract.createProject(
            "Run Advertising Campaign",
            "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore"
            , { gasLimit: 1000000, value: 10000000 }
        );
        const rcMint = await propTx.wait();
        const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
        const [projectTokenId] = eventMint.args;

        var totalBalance = await taskContract.getTotalBalance();

        expect(totalBalance).to.equal(10000000);

        let taskContractInst = taskContract.connect(signers[1]);

        var tokenId = await membersContract.getTokenId(signers[1].address);

        var proposalTx = await taskContractInst.createProposal(
            tokenId,
            projectTokenId,
            "I will do this because im smart",
            8000,
            { gasLimit: 1000000 }
        );
        const rc = await proposalTx.wait();
        const event = rc.events.find(event => event.event === 'Proposal');
        const [proposalId] = event.args;

        var proposalDetails = await taskContractInst.getProposalDetails(projectTokenId, proposalId);

        var projectDetailsInitial = await taskContract.getProjectDetails(projectTokenId);
        expect(projectDetailsInitial.amountFunded).to.equal(10000000);

        var proposalHash = await taskContractInst.generateProposalHash("I will do this because im smart", projectTokenId, tokenId);

        expect(proposalDetails.proposalHash).to.equal(proposalHash);

        let approveTx = await taskContract.populateTransaction.ownerApproveProposal(projectTokenId, proposalId);
        gasEstimate = await ethers.provider.estimateGas(approveTx);
        approveTx.gasLimit = gasEstimate;
        let txResponse = await signers[0].sendTransaction(approveTx);
        await txResponse.wait();

        var state = await taskContract.projectState(projectTokenId);
        expect(state).to.equal(0);

        let propCreatorApproveTx = await taskContractInst.populateTransaction.approveProposal(projectTokenId, proposalId);
        gasEstimate = await ethers.provider.estimateGas(propCreatorApproveTx);
        propCreatorApproveTx.gasLimit = gasEstimate;
        let propCreatorTxResponse = await signers[1].sendTransaction(propCreatorApproveTx);
        await propCreatorTxResponse.wait();

        var stateApproved = await taskContract.projectState(projectTokenId);

        expect(stateApproved).to.equal(1);

        var completeProposalTx = await taskContractInst.populateTransaction.completeProposal(
            projectTokenId,
            proposalId
        );

        gasEstimate = await ethers.provider.estimateGas(completeProposalTx);
        completeProposalTx.gasLimit = gasEstimate;
        let completeResponse = await signers[1].sendTransaction(completeProposalTx);
        await completeResponse.wait();

        var usersBalance = await ethers.provider.getBalance(signers[1].address);


        var ownerCompleteProposalTx = await taskContract.populateTransaction.completeProject(
            projectTokenId
        );

        gasEstimate = await ethers.provider.estimateGas(ownerCompleteProposalTx);
        ownerCompleteProposalTx.gasLimit = gasEstimate;
        let completeOwnerResponse = await signers[0].sendTransaction(ownerCompleteProposalTx);
        await completeOwnerResponse.wait();

        var usersNewBalance = await ethers.provider.getBalance(signers[1].address);

        const BigNumber = require('bignumber.js');

        const balance = new BigNumber(usersBalance.toString());
        const otherNumber = new BigNumber(usersNewBalance.toString());
        
        const result = balance.plus(10000000);


        expect(otherNumber.toString()).to.equal(result.toString());


    });
    
    // cancel project
    //ensure funds are returned
    it("can create a proposal for a task and then cancel the project", async () => {
        const { factoryContract, membersContract, boardContract, memberVotesContract, projectTokenContract, taskContract, signers } = await loadFixture(taskFixture);

        var usersBalanceBefore = await ethers.provider.getBalance(signers[0].address);

        var propTx = await taskContract.createProject(
            "Run Advertising Campaign",
            "I need someone to put a picture of my dog on a big billboard on 3rd steet in Baltimore"
            , { gasLimit: 1000000, value: 10000000 }
        );
        const rcMint = await propTx.wait();
        
        let gasPrice = await ethers.provider.getGasPrice();  // Fetch the current gas price

        let etherSpentOnGasFirst = rcMint.gasUsed.mul(gasPrice);  

        const eventMint = rcMint.events.find(event => event.event === "ProjectCreated");
        const [projectTokenId] = eventMint.args;

        var totalBalance = await taskContract.getTotalBalance();

        expect(totalBalance).to.equal(10000000);

        var canceTx = await taskContract.populateTransaction.cancelProject(
            projectTokenId
        );

        var projectState = await taskContract.projectState(projectTokenId);

        expect(projectState).to.equal(0);

        gasEstimate = await ethers.provider.estimateGas(canceTx);
        canceTx.gasLimit = gasEstimate;
        let cancelResponse = await signers[0].sendTransaction(canceTx);
        var cancelResponseTx = await cancelResponse.wait();

        let etherSpentOnGasSecond = cancelResponseTx.gasUsed.mul(gasPrice);  
        const BigNumber = require('bignumber.js');
       
        var usersBalanceAfter = await ethers.provider.getBalance(signers[0].address);

        let before = new BigNumber(usersBalanceBefore.toString());

        var SecondGas = new BigNumber(etherSpentOnGasSecond.toString())
        var FirstGas = new BigNumber(etherSpentOnGasFirst.toString())
        var totalGas = SecondGas.plus(FirstGas);
        
        let after = new BigNumber(usersBalanceAfter.toString())
            .plus(totalGas);


        var totalBalance = await taskContract.getTotalBalance();

        expect(totalBalance).to.equal(0);

        // The difference should be less than the margin of error
        expect(before.toString()).to.equal(after.toString());

        var projectStatel = await taskContract.projectState(projectTokenId);

        expect(projectStatel).to.equal(2);


    });

    //disputeProposal

});
