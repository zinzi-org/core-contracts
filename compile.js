const path = require("path");
const fs = require('fs-extra');
const solc = require("solc");
const { Console } = require("console");


const noDelegate = path.resolve(__dirname, "contracts/lib", "NoDelegateCall.sol");
const noDelegateSource = fs.readFileSync(noDelegate, "utf8");

const stringsPath = path.resolve(__dirname, "contracts/lib", "Strings.sol");
const stringsSource = fs.readFileSync(stringsPath, "utf8");

const ERC165Path = path.resolve(__dirname, "contracts/lib", "ERC165.sol");
const ERC165PathSource = fs.readFileSync(ERC165Path, "utf8");

const IERC165Path = path.resolve(__dirname, "contracts/lib", "IERC165.sol");
const IERC165PathSource = fs.readFileSync(IERC165Path, "utf8");

const IERC721Path = path.resolve(__dirname, "contracts/lib", "IERC721.sol");
const IERC721PathSource = fs.readFileSync(IERC721Path, "utf8");

const IERC721MetaDataPath = path.resolve(__dirname, "contracts/lib", "IERC721MetaData.sol");
const IERC721MetaDataPathSource = fs.readFileSync(IERC721MetaDataPath, "utf8");

const IERC721ReceiverPath = path.resolve(__dirname, "contracts/lib", "IERC721Receiver.sol");
const IERC721ReceiverPathSource = fs.readFileSync(IERC721ReceiverPath, "utf8");

const memberBoardFactoryPath = path.resolve(__dirname, "contracts", "MemberBoardFactory.sol");
const memberBoardFactorySource = fs.readFileSync(memberBoardFactoryPath, "utf8");

const memberBoardPath = path.resolve(__dirname, "contracts", "MemberBoard.sol");
const memberBoardSource = fs.readFileSync(memberBoardPath, "utf8");

const memberPath = path.resolve(__dirname, "contracts", "Member.sol");
const memberSource = fs.readFileSync(memberPath, "utf8");

const userPath = path.resolve(__dirname, "contracts", "User.sol");
const userSource = fs.readFileSync(userPath, "utf8");

const governorPath = path.resolve(__dirname, "contracts", "Governor.sol");
const governorSource = fs.readFileSync(governorPath, "utf8");

const governorCountingSimplePath = path.resolve(__dirname, "contracts", "GovernorCountingSimple.sol");
const governorCountingSimplePathSource = fs.readFileSync(governorCountingSimplePath, "utf8");

const governorSettingsPath = path.resolve(__dirname, "contracts", "GovernorSettings.sol");
const governorSettingsSource = fs.readFileSync(governorSettingsPath, "utf8");


var input = {
    language: 'Solidity',
    sources: {
        'MemberBoardFactory.sol': {
            content: memberBoardFactorySource
        },
        'MemberBoard.sol': {
            content: memberBoardSource
        },
        'Member.sol': {
            content: memberSource
        },
        'User.sol': {
            content: userSource
        }
    },
    settings: {
        outputSelection: {
            '*': {
                '*': ['*']
            }
        }
    }
};


const buildPath = path.resolve(__dirname, 'build');
fs.removeSync(buildPath);


function findImports(path) {
    if (path === "lib/NoDelegateCall.sol") return { contents: `${noDelegateSource}` };
    if (path === "MemberBoardFactory.sol") return { contents: `${memberBoardFactorySource}` };
    if (path === "MemberBoard.sol") return { contents: `${memberBoardSource}` };
    if (path === "Member.sol") return { contents: `${memberSource}` };
    if (path === "User.sol") return { contents: `${userSource}` };
    if (path === "lib/ERC165.sol") return { contents: `${ERC165PathSource}` };
    if (path === "lib/IERC165.sol") return { contents: `${IERC165PathSource}` };
    if (path === "lib/IERC721.sol") return { contents: `${IERC721PathSource}` };
    if (path === "lib/IERC721Metadata.sol") return { contents: `${IERC721MetaDataPathSource}` };
    if (path === "lib/IERC721Receiver.sol") return { contents: `${IERC721ReceiverPathSource}` };
    if (path === "lib/NoDelegateCall.sol") return { contents: `${noDelegateSource}` };
    if (path === "lib/Strings.sol") return { contents: `${stringsSource}` };
    else return { error: "File not found" };
}

let output = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));


if (output.errors) {
    console.log("++++++++++++++++++++++++++++++++++++++++++++++++++++++ERRORS++++++++++++++++++++++++++++++++++++++++++++++++++++++");
    for (var i = 0; i < output.errors.length; i++) {
        console.log(output.errors[i].formattedMessage);
    }
    console.log("++++++++++++++++++++++++++++++++++++++++++++++++++++++ERRORS++++++++++++++++++++++++++++++++++++++++++++++++++++++");
    return;
}

fs.ensureDirSync(buildPath);

for (let contract in output.contracts["MemberBoardFactory.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["MemberBoardFactory.sol"][contract]
    );
}

for (let contract in output.contracts["MemberBoard.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["MemberBoard.sol"][contract]
    );
}

for (let contract in output.contracts["Member.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["Member.sol"][contract]
    );
}


for (let contract in output.contracts["User.sol"]) {
    fs.outputJsonSync(
        path.resolve(buildPath, contract.replace(':', '') + '.json'),
        output.contracts["User.sol"][contract]
    );
}







console.log("Build compile complete!");