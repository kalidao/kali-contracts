// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

/// @notice Modern and gas-optimized ERC-20 + EIP-2612 implementation with COMP-style governance and pausing.
/// @author Modified from Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/erc20/ERC20.sol)
/// License-Identifier: AGPL-3.0-only
abstract contract KaliDAOxToken {
    /// -----------------------------------------------------------------------
    /// EVENTS
    /// -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );

    event PauseFlipped();

    /// -----------------------------------------------------------------------
    /// ERRORS
    /// -----------------------------------------------------------------------

    error NoArrayParity();

    error Paused();

    error SignatureExpired();

    error NotDetermined();

    error InvalidSignature();

    error Uint32max();

    error Uint96max();

    /// -----------------------------------------------------------------------
    /// IMMUTABLE STORAGE
    /// -----------------------------------------------------------------------

    uint8 public constant decimals = 18;

    function INITIAL_CHAIN_ID() internal pure returns (uint256) {
        return _getArgUint256(66);
    }

    function name() public pure virtual returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(8)));
    }

    function symbol() public pure virtual returns (string memory) {
        return string(abi.encodePacked(_getArgUint256(20)));
    }

    function _getArgUint256(uint256 argOffset)
        internal
        pure
        virtual
        returns (uint256 arg)
    {
        uint256 offset = _getImmutableArgsOffset();

        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    function _getImmutableArgsOffset()
        internal
        pure
        virtual
        returns (uint256 offset)
    {
        assembly {
            offset := sub(
                calldatasize(),
                add(shr(240, calldataload(sub(calldatasize(), 2))), 2)
            )
        }
    }

    /// -----------------------------------------------------------------------
    /// ERC-20 STORAGE
    /// -----------------------------------------------------------------------

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /// -----------------------------------------------------------------------
    /// EIP-2612 STORAGE
    /// -----------------------------------------------------------------------

    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /// -----------------------------------------------------------------------
    /// DAO STORAGE
    /// -----------------------------------------------------------------------

    bool public paused;

    mapping(address => address) internal _delegates;

    mapping(address => mapping(uint256 => Checkpoint)) public checkpoints;

    mapping(address => uint256) public numCheckpoints;

    struct Checkpoint {
        uint32 fromTimestamp;
        uint96 votes;
    }

    /// -----------------------------------------------------------------------
    /// INITIALIZER
    /// -----------------------------------------------------------------------

    function _init(
        bool paused_,
        address[] memory voters_,
        uint256[] memory shares_
    ) internal virtual {
        if (voters_.length != shares_.length) revert NoArrayParity();

        paused = paused_;

        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();

        address voter;

        uint256 shares;

        uint256 supply;

        for (uint256 i; i < voters_.length; ) {
            voter = voters_[i];

            shares = shares_[i];

            supply += shares;

            _moveDelegates(address(0), voter, shares);

            emit Transfer(address(0), voter, shares);

            // cannot realistically overflow on human timescales
            unchecked {
                balanceOf[voter] += shares;

                ++i;
            }
        }

        totalSupply = _safeCastTo96(supply);
    }

    /// -----------------------------------------------------------------------
    /// ERC-20 LOGIC
    /// -----------------------------------------------------------------------

    function approve(address spender, uint256 amount)
        public
        payable
        virtual
        returns (bool)
    {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount)
        public
        payable
        virtual
        notPaused
        returns (bool)
    {
        balanceOf[msg.sender] -= amount;

        // cannot overflow because the sum of all user
        // balances can't exceed the max uint96 value
        unchecked {
            balanceOf[to] += amount;
        }

        _moveDelegates(delegates(msg.sender), delegates(to), amount);

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public payable virtual notPaused returns (bool) {
        if (allowance[from][msg.sender] != type(uint256).max)
            allowance[from][msg.sender] -= amount;

        balanceOf[from] -= amount;

        // cannot overflow because the sum of all user
        // balances can't exceed the max uint96 value
        unchecked {
            balanceOf[to] += amount;
        }

        _moveDelegates(delegates(from), delegates(to), amount);

        emit Transfer(from, to, amount);

        return true;
    }

    /// -----------------------------------------------------------------------
    /// EIP-2612 LOGIC
    /// -----------------------------------------------------------------------

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            block.chainid == INITIAL_CHAIN_ID()
                ? INITIAL_DOMAIN_SEPARATOR
                : _computeDomainSeparator();
    }

    function _computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name())),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual {
        if (block.timestamp > deadline) revert SignatureExpired();

        // cannot realistically overflow on human timescales
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            if (recoveredAddress == address(0)) revert InvalidSignature();

            if (recoveredAddress != owner) revert InvalidSignature();

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    /// -----------------------------------------------------------------------
    /// DAO LOGIC
    /// -----------------------------------------------------------------------

    modifier notPaused() {
        if (paused) revert Paused();

        _;
    }

    function delegates(address delegator)
        public
        view
        virtual
        returns (address)
    {
        address current = _delegates[delegator];

        return current == address(0) ? delegator : current;
    }

    function delegate(address delegatee) public payable virtual {
        _delegate(msg.sender, delegatee);
    }

    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public payable virtual {
        if (block.timestamp > deadline) revert SignatureExpired();

        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Delegation(address delegatee,uint256 nonce,uint256 deadline)"
                            ),
                            delegatee,
                            nonce,
                            deadline
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        if (recoveredAddress == address(0)) revert InvalidSignature();

        // cannot realistically overflow on human timescales
        unchecked {
            if (nonce != nonces[recoveredAddress]++) revert InvalidSignature();
        }

        _delegate(recoveredAddress, delegatee);
    }

    function getCurrentVotes(address account)
        public
        view
        virtual
        returns (uint96)
    {
        // this is safe from underflow because decrement only occurs if `nCheckpoints` is positive
        unchecked {
            uint256 nCheckpoints = numCheckpoints[account];

            return
                nCheckpoints != 0
                    ? checkpoints[account][nCheckpoints - 1].votes
                    : 0;
        }
    }

    function getPriorVotes(address account, uint256 timestamp)
        public
        view
        virtual
        returns (uint96)
    {
        if (block.timestamp <= timestamp) revert NotDetermined();

        uint256 nCheckpoints = numCheckpoints[account];

        if (nCheckpoints == 0) return 0;

        // this is safe from underflow because decrement only occurs if `nCheckpoints` is positive
        unchecked {
            if (
                checkpoints[account][nCheckpoints - 1].fromTimestamp <=
                timestamp
            ) return checkpoints[account][nCheckpoints - 1].votes;

            if (checkpoints[account][0].fromTimestamp > timestamp) return 0;

            uint256 lower;

            // this is safe from underflow because decrement only occurs if `nCheckpoints` is positive
            uint256 upper = nCheckpoints - 1;

            while (upper > lower) {
                // this is safe from underflow because ceil is provided
                uint256 center = upper - (upper - lower) / 2;

                Checkpoint memory cp = checkpoints[account][center];

                if (cp.fromTimestamp == timestamp) {
                    return cp.votes;
                } else if (cp.fromTimestamp < timestamp) {
                    lower = center;
                } else {
                    upper = center - 1;
                }
            }

            return checkpoints[account][lower].votes;
        }
    }

    function _delegate(address delegator, address delegatee) internal virtual {
        address currentDelegate = delegates(delegator);

        _delegates[delegator] = delegatee;

        _moveDelegates(currentDelegate, delegatee, balanceOf[delegator]);

        emit DelegateChanged(delegator, currentDelegate, delegatee);
    }

    function _moveDelegates(
        address srcRep,
        address dstRep,
        uint256 amount
    ) internal virtual {
        if (srcRep != dstRep && amount != 0) {
            if (srcRep != address(0)) {
                uint256 srcRepNum = numCheckpoints[srcRep];

                uint256 srcRepOld;

                // this is safe from underflow because decrement only occurs if `srcRepNum` is positive
                unchecked {
                    srcRepOld = srcRepNum != 0
                        ? checkpoints[srcRep][srcRepNum - 1].votes
                        : 0;
                }

                uint256 srcRepNew = srcRepOld - amount;

                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                uint256 dstRepNum = numCheckpoints[dstRep];

                uint256 dstRepOld;

                // this is safe from underflow because decrement only occurs if `dstRepNum` is positive
                unchecked {
                    dstRepOld = dstRepNum != 0
                        ? checkpoints[dstRep][dstRepNum - 1].votes
                        : 0;
                }

                uint256 dstRepNew = dstRepOld + amount;

                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint256 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    ) internal virtual {
        unchecked {
            // this is safe from underflow because decrement only occurs if `nCheckpoints` is positive
            if (
                nCheckpoints != 0 &&
                checkpoints[delegatee][nCheckpoints - 1].fromTimestamp ==
                block.timestamp
            ) {
                checkpoints[delegatee][nCheckpoints - 1].votes = _safeCastTo96(
                    newVotes
                );
            } else {
                checkpoints[delegatee][nCheckpoints] = Checkpoint(
                    _safeCastTo32(block.timestamp),
                    _safeCastTo96(newVotes)
                );

                // cannot realistically overflow on human timescales
                ++numCheckpoints[delegatee];
            }
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    /// -----------------------------------------------------------------------
    /// MINT/BURN LOGIC
    /// -----------------------------------------------------------------------

    function _mint(address to, uint256 amount) internal virtual {
        _safeCastTo96(totalSupply + amount);

        // cannot overflow because the sum of all user
        // balances can't exceed the max uint96 value
        unchecked {
            balanceOf[to] += amount;
        }

        _moveDelegates(address(0), delegates(to), amount);

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // cannot underflow because a user's balance
        // will never be larger than the total supply
        unchecked {
            totalSupply -= amount;
        }

        _moveDelegates(delegates(from), address(0), amount);

        emit Transfer(from, address(0), amount);
    }

    function burn(uint256 amount) public payable virtual {
        _burn(msg.sender, amount);
    }

    function burnFrom(address from, uint256 amount) public payable virtual {
        if (allowance[from][msg.sender] != type(uint256).max)
            allowance[from][msg.sender] -= amount;

        _burn(from, amount);
    }

    /// -----------------------------------------------------------------------
    /// PAUSE LOGIC
    /// -----------------------------------------------------------------------

    function _flipPause() internal virtual {
        paused = !paused;

        emit PauseFlipped();
    }

    /// -----------------------------------------------------------------------
    /// SAFECAST LOGIC
    /// -----------------------------------------------------------------------

    function _safeCastTo32(uint256 x) internal pure virtual returns (uint32) {
        if (x > type(uint32).max) revert Uint32max();

        return uint32(x);
    }

    function _safeCastTo96(uint256 x) internal pure virtual returns (uint96) {
        if (x > type(uint96).max) revert Uint96max();

        return uint96(x);
    }
}
