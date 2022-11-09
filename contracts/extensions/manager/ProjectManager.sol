// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.14;
 
/// @notice Sporos DAO project manager interface
interface IProjectManagement {
  /**
        @notice a DAO authorized manager can order mint of tokens to contributors within the project limits.
     */
  function mintShares(address to, uint256 amount) external payable;
 
  // Future versions will support tribute of work in exchange for tokens
  // function submitTribute(address fromContributor, bytes[] nftTribute, uint256 requestedRewardAmount) external payable;
  // function processTribute(address contributor, bytes[] nftTribute, uint256 rewardAmount) external payable;
}
 
 
/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
 
    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
 
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);
 
    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
 
    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);
 
    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);
 
    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);
 
    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
 
 
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.
 
    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
 
    uint256 private _status;
 
    constructor() {
        _status = _NOT_ENTERED;
    }
 
    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
 
        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
 
        _;
 
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}
 
/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
 
/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
 
    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
 
    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
 
    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);
 
    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);
 
    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
 
    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
 
    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
 
    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;
 
    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;
 
    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);
 
    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}
 
/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
 
/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
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

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

/**
    @notice Project management extension for KaliDAO
 
    DAO token holders aprove and activate Projects that authorize a specific project manager to
    issue reward tokens to contributors in accordance with
    the terms of the project:
    - budget: A manager can order mint of DAO tokens up to a given budget.
    - deadline: A manager cannot order token mints after the project deadline expires.
    - goals: A manager is expected to act in accordance with the goals outlined in the DAO project proposal.
 
    A project's manager, reward token, budget, deadline and goals can be updated via DAO proposal.
 
    A project has exactly one manager. A manager may be assigned to 0, 1 or multiple projects.
 
    Modeled after KaliShareManager.sol
    https://github.com/kalidao/kali-contracts/blob/main/contracts/extensions/manager/KaliShareManager.sol
 
    (c) 2022 sporosdao.eth & kalidao.eth
 
    @author ivelin.eth
    @custom:coauthor audsssy.eth
 
 */
contract ProjectManagement is ReentrancyGuard {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
 
    event ExtensionSet(
        address indexed dao,
        Project project
    );
 
    event ExtensionCalled(
        address indexed dao,
        bytes[] updates
    );
 
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------
 
    error ProjectNotEnoughBudget();
    error ProjectExpired();
    error ProjectManagerNeedsDaoTokens();
    error ProjectUnknown();
    error ForbiddenDifferentDao();
    error ForbiddenSenderNotManager();
    error TokenNotSet();
    error TokenNotFound();
    error AmountInsufficient();
 
    /// -----------------------------------------------------------------------
    /// Project Management Storage
    /// -----------------------------------------------------------------------
 
    struct Project {
        uint256 id; // unique project identifier
        address dao; // the address of the DAO that this project belongs to
        address manager; // manager assigned to this project
        address token; // REWARD TOKEN
        uint256 tokenId; // REWARD TOKEN ID
        uint256 budget; // maximum allowed tokens the manager is authorized to mint
        address rightsToken; // RIGHTS TOKEN USED IF NFT IS REWARD TOKEN
        uint32 deadline; // deadline date of the project
        string goals; // structured text referencing key goals for the manager's mandate
    }
 
    // unique project id auto-increment
    // Starts at 100 leaving 0-99 as reserved for potential future special use cases.
    // 0 is reserved for a new project proposal that has not been processed and assigned an id yet.
    uint256 public nextProjectId = 100;
 
    // project id -> Project mapping
    mapping(uint256 => Project) public projects;
 
    /// -----------------------------------------------------------------------
    /// Management Settings
    /// -----------------------------------------------------------------------
 
    /**
 
      @notice A DAO calls this method to activate an approved Project Proposal.
 
      @param extensionData : Contains DAO approved projects parameters; either new or existing project updates. New projects must have id of 0.
 
     */
    function setExtension(bytes calldata extensionData) external payable {
 
        // console.log("(EVM)---->: setExtension called by ", msg.sender);
        (
            uint256 id,
            address manager,
            address token,
            uint256 tokenId,
            uint256 budget,
            uint32 deadline,
            string  memory goals
        ) = abi.decode(
            extensionData,
            (uint256, address, address, uint256, uint256, uint32, string)
        );
 
        // A project maanger must be a trusted DAO token holder
        if (IERC20(msg.sender).balanceOf(manager) == 0) revert ProjectManagerNeedsDaoTokens();
 
        Project memory projectUpdate;
        projectUpdate.id = id;
        projectUpdate.manager = manager;
        projectUpdate.token = token;
        projectUpdate.tokenId = tokenId;
        projectUpdate.budget = budget;
        projectUpdate.deadline = deadline;
        projectUpdate.goals = goals;
        projectUpdate.dao = msg.sender;
 
        if (token == address(0)) {
            projectUpdate.token = projectUpdate.dao;
            projectUpdate.tokenId = 0;
        } else if (IERC20(token).totalSupply() != 0){
            projectUpdate.token = token;
            projectUpdate.tokenId = 0;
 
            IERC20(token).transferFrom(projectUpdate.dao, address(this), budget);
        } else if (IERC721(token).ownerOf(tokenId) == projectUpdate.dao){
            projectUpdate.token = token;
            projectUpdate.tokenId = tokenId;
 
            IERC721(token).safeTransferFrom(projectUpdate.dao, address(this), tokenId);
        } else {
            revert TokenNotSet();
        }
 
        Project memory savedProject;
 
        if (projectUpdate.id == 0) {
            // id == 0 means new Project creation
            // assign next id and auto increment id counter
            projectUpdate.id = nextProjectId;
            // cannot realistically overflow
            unchecked {
                ++nextProjectId;
            }
        } else {
            savedProject = projects[projectUpdate.id];
            // someone is trying to update a non-existent project
            if (savedProject.id == 0) revert ProjectUnknown();
            // someone is trying to update a project that belongs to a different DAO address
            // only the DAO that created a project can modify it
            if (savedProject.dao != projectUpdate.dao) revert ForbiddenDifferentDao();
        }
        // if all safety checks passed, create/update project
        projects[projectUpdate.id] = projectUpdate;
 
        emit ExtensionSet(projectUpdate.dao, projectUpdate);
    }
 
    /// -----------------------------------------------------------------------
    /// Project Management Logic
    /// -----------------------------------------------------------------------
 
    /**
        @notice An authorized project manager calls this method to order a DAO token mint to contributors.
 
        @param dao - the dao that the project manager is authorized to manage.
        @param extensionData - contains a list of tuples: (project id, recipient contributor account, amount to mint).
     */
    function callExtension(address dao, bytes[] calldata extensionData)
        external
        payable
        nonReentrant
    {
        // console.log("(EVM)---->: callExtension called. DAO address:", dao);
 
        for (uint256 i; i < extensionData.length;) {
            // console.log("(EVM)----> i = ", i);
            (
                uint256 projectId,
                address contributor,
                uint256 amount
            ) = abi.decode(extensionData[i], (uint256, address, uint256));
 
            Project storage project = projects[projectId];
 
            // console.log("(EVM)----> projectId, contributor, amount:", projectId, contributor, amount);
            // console.log("(EVM)----> projectId, contributor, deliverable:", projectId, contributor, tribute);
 
            if (project.id == 0) revert ProjectUnknown();
 
            if (project.manager != msg.sender) revert ForbiddenSenderNotManager();
 
            if (project.deadline < block.timestamp) revert ProjectExpired();
 
            if (project.budget < amount) revert ProjectNotEnoughBudget();
 
            project.budget -= amount;
 
            // console.log("(EVM)----> updated project budget:", project.budget);
 
            if (project.token == dao) {
                IProjectManagement(dao).mintShares(
                    contributor,
                    amount
                );
            } else if (IERC20(project.token).totalSupply() != 0){
                IERC20(project.token).transferFrom(address(this), contributor, amount);
            } else if (IERC721(project.token).supportsInterface(0x80ac58cd)){
                // mint NFT shards
               if (project.rightsToken == address(0)) {
                ERC20 token = new ERC20("pmToken", "PM", 18);
                project.rightsToken = address(token);
                token.mint(contributor, 1);
               } else {
                ERC20(project.rightsToken).mint(contributor, 1);
               }
            } else {
                revert TokenNotFound();
            }

            // cannot realistically overflow
            unchecked {
                ++i;
            }
        }
 
        // console.log("(EVM)----> firing event ExtensionCalled()");
 
        emit ExtensionCalled(dao, extensionData);
    }
 
    // Claim NFT
    function claim (uint256 projectId, address token, uint256 tokenId) external payable nonReentrant {
        Project storage project = projects[projectId];

        if (IERC20(project.rightsToken).balanceOf(msg.sender) != IERC20(token).totalSupply()) revert AmountInsufficient();
 
        IERC721(project.token).safeTransferFrom(address(this), msg.sender, tokenId);
    }
}
