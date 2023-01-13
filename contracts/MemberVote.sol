// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.17;

import "./lib/IERC20Metadata.sol";
import "./lib/Context.sol";
import "./lib/IVotes.sol";
import "./lib/SafeCast.sol";
import "./lib/Counters.sol";
import "./lib/Math.sol";
import "./lib/ECDSA.sol";
import "./lib/EIP712.sol";
import "./lib/IERC20.sol";

import "hardhat/console.sol";

contract MemberVote is Context, IERC20, IERC20Metadata, IVotes, EIP712 {
    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    using Counters for Counters.Counter;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    address public _boardAddress;

    mapping(address => uint256) private _balances;
    mapping(address => address) private _delegates;
    mapping(address => Checkpoint[]) private _checkpoints;

    Checkpoint[] private _totalSupplyCheckpoints;

    mapping(address => Counters.Counter) private _nonces;

    bytes32 private constant _DELEGATION_TYPEHASH =
        keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    constructor(
        string memory name_,
        string memory symbol_,
        address boardAddress
    ) EIP712(name_, "1") {
        _name = name_;
        _symbol = symbol_;
        _boardAddress = boardAddress;
    }

    function assignVoteToken(address who) public {
        require(msg.sender == _boardAddress);
        _mint(who, 1);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    //method that will always fail and does not show compile warnings
    function transfer(address to, uint256 amount) public view returns (bool) {
        require(true == false, "Must delegate votes not transfer");
        require(to == address(this));
        require(amount == 0);
        return false;
    }

    //method that will always fail and does not show compile warnings
    function allowance(
        address owner,
        address spender
    ) public view returns (uint256) {
        require(owner == address(this));
        require(spender == address(0));
        return 0;
    }

    //method that will always fail and does not show compile warnings
    function approve(
        address spender,
        uint256 amount
    ) public pure returns (bool) {
        require(true == false, "Must delegate votes not transfer");
        require(spender == address(0));
        require(amount == 0);
        return false;
    }

    //method that will always fail and does not show compile warnings
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public pure returns (bool) {
        require(true == false, "Must delegate votes not transfer");
        require(from == address(0));
        require(to == address(0));
        require(amount == 0);
        return false;
    }

    function checkpoints(
        address account,
        uint32 pos
    ) public view returns (Checkpoint memory) {
        return _checkpoints[account][pos];
    }

    function numCheckpoints(address account) public view returns (uint32) {
        return SafeCast.toUint32(_checkpoints[account].length);
    }

    function delegateSafeCheck(address account) public view returns (address) {
        address del = _delegates[account];
        if (del == address(0)) {
            return account;
        } else {
            return del;
        }
    }

    function getVotes(address account) public view returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    function getPastVotes(
        address account,
        uint256 blockNumber
    ) public view override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }

    function getPastTotalSupply(
        uint256 blockNumber
    ) public view override returns (uint256) {
        require(blockNumber < block.number, "ERC20Votes: block not yet mined");
        return _checkpointsLookup(_totalSupplyCheckpoints, blockNumber);
    }

    function delegate(address delegatee) public {
        _delegate(_msgSender(), delegatee);
    }

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        require(block.timestamp <= expiry, "ERC20Votes: signature expired");
        address signer = ECDSA.recover(
            _hashTypedDataV4(
                keccak256(
                    abi.encode(_DELEGATION_TYPEHASH, delegatee, nonce, expiry)
                )
            ),
            v,
            r,
            s
        );
        require(nonce == _useNonce(signer), "ERC20Votes: invalid nonce");
        _delegate(signer, delegatee);
    }

    function _checkpointsLookup(
        Checkpoint[] storage ckpts,
        uint256 blockNumber
    ) private view returns (uint256) {
        uint256 length = ckpts.length;

        uint256 low = 0;
        uint256 high = length;

        if (length > 5) {
            uint256 mid = length - Math.sqrt(length);
            if (_unsafeAccess(ckpts, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(ckpts, mid).fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : _unsafeAccess(ckpts, high - 1).votes;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);

        require(
            totalSupply() <= _maxSupply(),
            "ERC20Votes: total supply risks overflowing votes"
        );

        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);

        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, amount);
    }

    function _maxSupply() internal pure returns (uint224) {
        return type(uint224).max;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        _moveVotingPower(
            delegateSafeCheck(from),
            delegateSafeCheck(to),
            amount
        );
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = delegateSafeCheck(delegator);
        uint256 delegatorBalance = balanceOf(delegator);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveVotingPower(
        address src,
        address dst,
        uint256 amount
    ) private {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    _checkpoints[src],
                    _subtract,
                    amount
                );
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }
            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    _checkpoints[dst],
                    _add,
                    amount
                );
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;

        Checkpoint memory oldCkpt = pos == 0
            ? Checkpoint(0, 0)
            : _unsafeAccess(ckpts, pos - 1);

        oldWeight = oldCkpt.votes;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && oldCkpt.fromBlock == block.number) {
            _unsafeAccess(ckpts, pos - 1).votes = SafeCast.toUint224(newWeight);
        } else {
            ckpts.push(
                Checkpoint({
                    fromBlock: SafeCast.toUint32(block.number),
                    votes: SafeCast.toUint224(newWeight)
                })
            );
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    function _unsafeAccess(
        Checkpoint[] storage ckpts,
        uint256 pos
    ) private pure returns (Checkpoint storage result) {
        assembly {
            mstore(0, ckpts.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     *
     * _Available since v4.1._
     */
    function _useNonce(address owner) internal returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }
}
