
// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
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
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity >=0.6.2;


/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/interfaces/IERC20.sol


// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

pragma solidity >=0.4.16;


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
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
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/interfaces/IERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

pragma solidity >=0.4.16;


// File: @openzeppelin/contracts/interfaces/IERC1363.sol


// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

pragma solidity >=0.6.2;



/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;



/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }
}

// File: @chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol


pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// File: ICOFolders/MYICO.sol


pragma solidity ^0.8.24;






interface IReferral {
    error ReferralAlreadyExists();
    error InvalidReferrer();
    error UnauthorizedHandler(address handler);
    error InvalidAddress();
    error InvalidRange(uint256 startIndex, uint256 endIndex);
    error AlreadyInitialize();
    error NotInitialize();
    error InsufficientRewardToken();

    event ReferralAdded(address indexed user, address indexed referrer);
    event ReferralReward(
        address indexed user,
        address indexed referrer,
        uint256 reward
    );

    function addReferral(address account_, address referrer_) external;
    function distributeRewards(address account_, uint256 tokenAmount_) external;
    function getReferrer(
        address user_
    ) external view returns (address referrer);
    function getReferralsCount(
        address referrer_
    ) external view returns (uint256);
    function getReferralRewards(
        address referrer_
    ) external view returns (uint256);
    function getDirectReferrals(
        address referrer_,
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (address[] memory users);
}

interface ISRXICO {
    error SaleTypeAlreadyCreated(SaleType saleType);
    error InsufficientSaleQuantity();
    error SaleNotLive(Status currentStatus);
    error SaleEnded();
    error InvalidRange(uint256 startIndex, uint256 endIndex);
    error MinBuyExceedsTotalSaleValue(
        uint256 minBuyUsd,
        uint256 totalSaleValueUsd
    );
    error MinBuyLimit(uint256 minBuy, uint256 given);
    error MaxBuyLimit(uint256 maxBuy, uint256 given);
    error EndTimeGreaterThanStart();
    error InvalidPriceFromOracle();
    error UnsupportedPaymentOptions();
    error NoTokensToBurn();
    error SaleNotEnded();
    error UnsoldTokenNotBurnable();
    error PriceFeedAddressMust();
    error InvalidOptionForTokenReceive();
    error AlreadyInitialize();
    error NotInitialize();
    error InvalidAddress();
    error NoClaimableBeforeLaunch();

    event BuyToken(
        address indexed user,
        address indexed referrer,
        uint256 amount,
        uint256 volume,
        SaleType saleType
    );
    event PaymentOptionUpdated(
        address indexed token,
        address indexed priceFeedAddress,
        bool enable,
        bool isStable
    );

    enum SaleType {
        PreSale,
        PrivateSale,
        PublicSale
    }

    enum Status {
        Upcoming,
        Live,
        Ended
    }

    enum SaleTokenOption {
        InstantTokenReceive,
        TokenReceiveAfterSaleEnd
    }

    struct ICO {
        uint256 saleRateInUsd;
        uint256 saleTokenAmount;
        uint256 saleQuantity;
        uint256 minBuyInUsd;
        uint256 maxBuyInUsd;
        SaleTokenOption saleTokenOption;
        uint256 startAt; // the time till when sale startAt - (in unix time)
        uint256 endAt; // the time till when sale endAt - (in unix time)
        Status status;
    }

    struct Contributor {
        address user;
        string coin; // token symbol
        uint256 amount; // usd
        uint256 volume; // token amount(quantity)
        uint256 at;
    }

    struct PaymentOption {
        address token;
        bool enable;
        bool isStable;
        address priceFeedAddress;
    }

    struct Claimable {
        uint256 amount; /// will claim amount
        uint256 claimed; /// after claimed
    }

    function saleType2IcoDetail(
        SaleType saleType_
    ) external view returns (ICO memory);
    function user2SaleType2ContributorList(
        address user_,
        SaleType saleType_,
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (Contributor[] memory);
    function user2SaleType2Contributor(
        address user_,
        SaleType saleType_
    ) external view returns (Contributor memory);
}

contract MYICO is ISRXICO, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(SaleType saleType => ICO) private _saleType2IcoDetail;
    mapping(SaleType saleType => address[]) private _saleType2Contributors;
    mapping(address user => mapping(SaleType saleType => Contributor[]))
        private _user2SaleType2ContributorList;
    mapping(address user => mapping(SaleType saleType => Contributor))
        private _user2SaleType2Contributor;
    mapping(address token => PaymentOption) private _paymentOption; /// if zero address true then  Native Coin
    mapping(address user => mapping(SaleType saleType => Claimable))
        private _user2SaleType2ClaimableDetail;
    address[] private _acceptedTokens;

    bool public isInitialized;
    IERC20 public saleToken;
    IReferral public referralContract;

    uint8 private constant _NATIVE_COIN_DECIMALS = 18; // EVM only
    uint256 public exchangelaunchDate;

    constructor() Ownable(_msgSender()) {}

    function initialize(
        address saleToken_,
        address referralContract_
    ) public onlyOwner {
        if (isInitialized) {
            revert AlreadyInitialize();
        }
        if (saleToken_ == address(0) || referralContract_ == address(0)) {
            revert InvalidAddress();
        }
        isInitialized = true;
        exchangelaunchDate = 1803902400; /// 1st March 2027
        saleToken = IERC20(saleToken_);
        referralContract = IReferral(referralContract_);
    }

    function updatereferralContract(
        address referralContract_
    ) public onlyOwner {
        referralContract = IReferral(referralContract_);
    }

    function updateExchangelaunchDate(
        uint256 exchangelaunchDate_
    ) public onlyOwner {
        exchangelaunchDate = exchangelaunchDate_;
    }

    function saleType2IcoDetail(
        SaleType saleType_
    ) public view returns (ICO memory) {
        return _saleType2IcoDetail[saleType_];
    }

    function totalContributorLengthForUser(
        address user_,
        SaleType saletType_
    ) public view returns (uint256) {
        return _user2SaleType2ContributorList[user_][saletType_].length;
    }

    function totalContributor(
        SaleType saletType_
    ) public view returns (uint256) {
        return _saleType2Contributors[saletType_].length;
    }

    function user2SaleType2Contributor(
        address user_,
        SaleType saleType_
    ) public view returns (Contributor memory) {
        return _user2SaleType2Contributor[user_][saleType_];
    }

    function user2SaleType2ContributorList(
        address user_,
        SaleType saletType_,
        uint256 startIndex_,
        uint256 endIndex_
    ) public view returns (Contributor[] memory result) {
        if (
            startIndex_ > endIndex_ ||
            endIndex_ > totalContributorLengthForUser(user_, saletType_)
        ) {
            revert InvalidRange(startIndex_, endIndex_);
        }
        uint256 length = endIndex_ - startIndex_;
        result = new Contributor[](length);

        uint256 currentIndex;
        for (uint256 i = startIndex_; i < endIndex_; ) {
            result[currentIndex] = _user2SaleType2ContributorList[user_][
                saletType_
            ][i];
            ++currentIndex;
            unchecked {
                ++i;
            }
        }
    }

    function saleType2Contributors(
        SaleType saletType_,
        uint256 startIndex_,
        uint256 endIndex_
    ) public view returns (address[] memory result) {
        if (
            startIndex_ > endIndex_ || endIndex_ > totalContributor(saletType_)
        ) {
            revert InvalidRange(startIndex_, endIndex_);
        }
        uint256 length = endIndex_ - startIndex_;
        result = new address[](length);

        uint256 currentIndex;
        for (uint256 i = startIndex_; i < endIndex_; ) {
            result[currentIndex] = _saleType2Contributors[saletType_][i];
            ++currentIndex;
            unchecked {
                ++i;
            }
        }
    }

    function user2SaleType2ClaimableDetail(
        address user_,
        SaleType saleType_
    ) public view returns (Claimable memory) {
        return _user2SaleType2ClaimableDetail[user_][saleType_];
    }

    function getAcceptedTokenList() public view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _acceptedTokens.length; ) {
            if (_paymentOption[_acceptedTokens[i]].enable) {
                ++count;
            }
            unchecked {
                ++i;
            }
        }

        address[] memory enabledTokens = new address[](count);
        if (count == 0) {
            return enabledTokens;
        }
        uint256 index = 0;
        for (uint256 i = 0; i < _acceptedTokens.length; ) {
            if (_paymentOption[_acceptedTokens[i]].enable) {
                enabledTokens[index] = _acceptedTokens[i];
                ++index;
            }
            unchecked {
                ++i;
            }
        }

        return enabledTokens;
    }

    function getPaymentOption(
        address token_
    ) public view returns (PaymentOption memory) {
        return _paymentOption[token_];
    }

    function setPaymentOption(
        address token_,
        address priceFeedAddress_,
        bool enable_,
        bool isStable_
    ) public onlyOwner {
        if (
            (token_ == address(0) || !isStable_) &&
            priceFeedAddress_ == address(0)
        ) {
            revert PriceFeedAddressMust();
        }

        if (_paymentOption[token_].token != token_ && token_ != address(0)) {
            _acceptedTokens.push(token_);
        }
        _paymentOption[token_] = PaymentOption({
            token: token_,
            enable: enable_,
            isStable: isStable_,
            priceFeedAddress: priceFeedAddress_
        });
        emit PaymentOptionUpdated(
            token_,
            priceFeedAddress_,
            enable_,
            isStable_
        );
    }

    function createSale(
        SaleType saleType_,
        uint256 saleRateInUsd_,
        uint256 saleTokenAmount_,
        uint256 minBuyInUsd_,
        uint256 maxBuyInUsd_,
        SaleTokenOption saleTokenOption_,
        uint256 startAt_,
        uint256 endAt_
    ) public onlyOwner {
        if (!isInitialized) {
            revert NotInitialize();
        }
        if (saleType2IcoDetail(saleType_).saleTokenAmount != 0) {
            revert SaleTypeAlreadyCreated(saleType_);
        }
        if (endAt_ < startAt_) {
            revert EndTimeGreaterThanStart();
        }

        if (minBuyInUsd_ > saleRateInUsd_ * saleTokenAmount_) {
            revert MinBuyExceedsTotalSaleValue(
                minBuyInUsd_,
                saleRateInUsd_ * saleTokenAmount_
            );
        }
        address _caller = _msgSender();
        saleToken.safeTransferFrom(_caller, address(this), saleTokenAmount_);

        _saleType2IcoDetail[saleType_] = ICO({
            saleRateInUsd: saleRateInUsd_,
            saleTokenAmount: saleTokenAmount_,
            saleQuantity: saleTokenAmount_,
            minBuyInUsd: minBuyInUsd_,
            maxBuyInUsd: maxBuyInUsd_,
            saleTokenOption: saleTokenOption_,
            startAt: startAt_ != 0 ? startAt_ : block.timestamp,
            endAt: endAt_,
            status: startAt_ != 0 ? Status.Upcoming : Status.Live
        });
    }

    function updateSaleTime(
        SaleType saleType_,
        uint256 startAt_,
        uint256 endAt_
    ) public onlyOwner {
        if (endAt_ < startAt_) {
            revert EndTimeGreaterThanStart();
        }
        _saleType2IcoDetail[saleType_].endAt = endAt_;
        if (startAt_ != 0) {
            _saleType2IcoDetail[saleType_].startAt = startAt_;
            _saleType2IcoDetail[saleType_].status = Status.Upcoming;
        } else {
            _saleType2IcoDetail[saleType_].startAt = block.timestamp;
            _saleType2IcoDetail[saleType_].status = Status.Live;
        }
    }

    function buy(
        SaleType saleType_,
        address token_,
        uint256 amount_,
        address referrer_
    ) public payable nonReentrant {
        if (!getPaymentOption(token_).enable) {
            revert UnsupportedPaymentOptions();
        }
        ICO memory saleDetail_ = saleType2IcoDetail(saleType_);
        if (saleDetail_.startAt > block.timestamp) {
            revert SaleNotLive(saleDetail_.status);
        }
        if (block.timestamp > saleDetail_.endAt) {
            revert SaleEnded();
        }
        address user_ = _msgSender();
        uint256 amountInUsd_ = getPaymentOption(token_).isStable
            ? amount_
            : calculateUSDAmount(
                token_,
                token_ != address(0) ? amount_ : msg.value
            );
        if (amountInUsd_ == 0) {
            revert InvalidPriceFromOracle();
        }
        token_ != address(0)
            ? _buyWithToken(
                saleDetail_,
                saleType_,
                user_,
                token_,
                amount_,
                amountInUsd_,
                referrer_
            )
            : _buyWithNativeCoin(
                saleDetail_,
                saleType_,
                user_,
                amountInUsd_,
                referrer_
            );
    }

    function _buyWithToken(
        ICO memory saleDetail_,
        SaleType saleType_,
        address account_,
        address token_,
        uint256 amount_,
        uint256 amountInUsd_,
        address referrer_
    ) private {
        if (amountInUsd_ < saleDetail_.minBuyInUsd) {
            revert MinBuyLimit(saleDetail_.minBuyInUsd, amountInUsd_);
        }

        if (amountInUsd_ > saleDetail_.maxBuyInUsd) {
            revert MaxBuyLimit(saleDetail_.maxBuyInUsd, amountInUsd_);
        }

        uint256 tokenAmount_ = (amountInUsd_ * 1e18) /
            getSaleTokenPrice(saleType_);

        if (saleDetail_.saleQuantity < tokenAmount_) {
            revert InsufficientSaleQuantity();
        }
        if (saleToken.balanceOf(address(this)) < tokenAmount_) {
            revert("Insufficient: SaleToken");
        }
        IERC20(token_).safeTransferFrom(account_, address(this), amount_);

        _saleType2IcoDetail[saleType_].saleQuantity -= tokenAmount_;

        if (_user2SaleType2Contributor[account_][saleType_].amount == 0) {
            _saleType2Contributors[saleType_].push(account_);
        }

        _user2SaleType2ContributorList[account_][saleType_].push(
            Contributor({
                user: account_,
                coin: IERC20Metadata(token_).symbol(),
                amount: amountInUsd_,
                volume: tokenAmount_,
                at: block.timestamp
            })
        );

        _user2SaleType2Contributor[account_][saleType_].amount += amountInUsd_;
        _user2SaleType2Contributor[account_][saleType_].volume += tokenAmount_;

        _saleTokenTransferOptions(
            saleDetail_,
            saleType_,
            account_,
            tokenAmount_
        );
        emit BuyToken(account_, referrer_, amount_, tokenAmount_, saleType_);

        if (referrer_ != address(0) && referrer_ != account_) {
            referralContract.addReferral(account_, referrer_);
            referralContract.distributeRewards(account_, tokenAmount_);
        }
    }

    function _buyWithNativeCoin(
        ICO memory saleDetail_,
        SaleType saleType_,
        address account_,
        uint256 amountInUsd_,
        address referrer_
    ) private {
        if (amountInUsd_ < saleDetail_.minBuyInUsd) {
            revert MinBuyLimit(saleDetail_.minBuyInUsd, amountInUsd_);
        }

        if (amountInUsd_ > saleDetail_.maxBuyInUsd) {
            revert MaxBuyLimit(saleDetail_.maxBuyInUsd, amountInUsd_);
        }

        uint256 tokenAmount_ = (amountInUsd_ * 1e18) /
            getSaleTokenPrice(saleType_);

        if (saleDetail_.saleQuantity < tokenAmount_) {
            revert InsufficientSaleQuantity();
        }
        if (saleToken.balanceOf(address(this)) < tokenAmount_) {
            revert("Insufficient: SaleToken");
        }
        _saleType2IcoDetail[saleType_].saleQuantity -= tokenAmount_;

        if (_user2SaleType2Contributor[account_][saleType_].amount == 0) {
            _saleType2Contributors[saleType_].push(account_);
        }

        _user2SaleType2ContributorList[account_][saleType_].push(
            Contributor({
                user: account_,
                coin: "Native",
                amount: amountInUsd_,
                volume: tokenAmount_,
                at: block.timestamp
            })
        );

        _user2SaleType2Contributor[account_][saleType_].amount += amountInUsd_;
        _user2SaleType2Contributor[account_][saleType_].volume += tokenAmount_;

        _saleTokenTransferOptions(
            saleDetail_,
            saleType_,
            account_,
            tokenAmount_
        );
        emit BuyToken(account_, referrer_, msg.value, tokenAmount_, saleType_);

        if (referrer_ != address(0) && referrer_ != account_) {
            referralContract.addReferral(account_, referrer_);
            referralContract.distributeRewards(account_, tokenAmount_);
        }
    }

    // function _saleTokenTransferOptions(
    //     address account_,
    //     uint256 tokenAmount_
    // ) private {
    //     saleToken.safeTransfer(account_, tokenAmount_);
    // }
    function _saleTokenTransferOptions(
        ICO memory saleDetail_,
        SaleType saleType_,
        address account_,
        uint256 tokenAmount_
    ) private {
        if (
            saleDetail_.saleTokenOption == SaleTokenOption.InstantTokenReceive
        ) {
            // Direct transfer
            saleToken.safeTransfer(account_, tokenAmount_);
        } else {
            // Store claimable for later (single fallback condition)
            _user2SaleType2ClaimableDetail[account_][saleType_]
                .amount += tokenAmount_;
        }
    }

    function claimSaleToken(SaleType saleType_) public nonReentrant {
        ICO memory saleDetail_ = saleType2IcoDetail(saleType_);
        /// Check if the sale has ended
        if (block.timestamp < saleDetail_.endAt) {
            revert SaleNotEnded();
        }
        address caller_ = _msgSender();
        Claimable memory claimable_ = user2SaleType2ClaimableDetail(
            caller_,
            saleType_
        );
        uint256 _remainingToken = claimable_.amount - claimable_.claimed;
        if (_remainingToken == 0) {
            revert("claimed");
        }
        if (
            saleDetail_.saleTokenOption ==
            SaleTokenOption.TokenReceiveAfterSaleEnd
        ) {
            _user2SaleType2ClaimableDetail[caller_][saleType_]
                .claimed = claimable_.amount;
            saleToken.safeTransfer(caller_, claimable_.amount);
        } else {
            revert InvalidOptionForTokenReceive();
        }
    }

    function calculateUSDAmount(
        address token_,
        uint256 amount_
    ) public view returns (uint256 usdAmount) {
        if (!getPaymentOption(token_).enable) {
            return 0;
        }
        /// Get price data for the token
        (int256 price_, uint8 priceDecimals_) = getPriceFromOracle(token_);
        uint256 priceUint_ = uint256(price_);

        /// Calculate USD amount with proper decimal handling
        /// Formula: (amount_ * price_) / (10 ^ tokenDecimal_)
        /// We ensure high precision by multiplying first
        uint8 decimals_ = (
            token_ != address(0)
                ? IERC20Metadata(token_).decimals()
                : _NATIVE_COIN_DECIMALS
        );
        usdAmount = (amount_ * priceUint_) / (10 ** decimals_);

        /// If the price decimals don't match our standard _PRICE_DECIMAL,
        /// adjust the result accordingly
        if (priceDecimals_ > decimals_) {
            usdAmount = usdAmount / (10 ** (priceDecimals_ - decimals_));
        } else if (priceDecimals_ < decimals_) {
            usdAmount = usdAmount * (10 ** (decimals_ - priceDecimals_));
        }
        return usdAmount;
    }

    function getSaleTokenPrice(
        SaleType saleType_
    ) public view returns (uint256) {
        ICO memory saleDetail_ = _saleType2IcoDetail[saleType_];

        // uint256 currentTime_ = block.timestamp;

        // /// Time elapsed since the sale started or until the sale ended
        // uint256 effectiveTime_ = currentTime_ > saleDetail_.endAt ? saleDetail_.endAt : currentTime_;
        // uint256 timeElapsed = effectiveTime_ > saleDetail_.startAt ? effectiveTime_ - saleDetail_.startAt : 0;

        // /// Adjusted sale rate after applying the percentage change for each interval
        uint256 adjustedSaleRate_ = saleDetail_.saleRateInUsd;

        // /// Apply rate change if both percentage and duration are set
        // if (saleDetail_.maxBounceInPercent != 0 && saleDetail_.decreseBouncePerDayInPercent !=0) {
        //     uint256 intervals = timeElapsed / saleDetail_.decreseBouncePerDayInPercent;
        //     for (uint256 i = 0; i < intervals;) {
        //         adjustedSaleRate_ += (saleDetail_.saleRateInUsd * saleDetail_.maxBounceInPercent) / 1e4;
        //         unchecked {
        //             ++i;
        //         }
        //     }
        // }
        return adjustedSaleRate_;
    }

    function getPriceFromOracle(
        address token_
    ) public view returns (int256 price, uint8 decimals) {
        address priceFeedAddress_ = _paymentOption[token_].priceFeedAddress;
        if (priceFeedAddress_ == address(0)) {
            return (0, 0);
        }
        AggregatorV3Interface priceFeed_ = AggregatorV3Interface(
            priceFeedAddress_
        );
        (, int256 latestPrice_, , , ) = priceFeed_.latestRoundData();

        return (latestPrice_, priceFeed_.decimals());
    }

    function transferTokens(
        IERC20 token_,
        address to_,
        uint256 amount_
    ) public onlyOwner {
        token_.safeTransfer(to_, amount_);
    }

    function transferNativeCoin(
        address payable to_,
        uint256 amount_
    ) public onlyOwner {
        (bool success, ) = to_.call{value: amount_}("");
        if (!success) {
            revert("Tx:Failed");
        }
    }

    receive() external payable {}
}
