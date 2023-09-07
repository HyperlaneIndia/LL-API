// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@hyperlane-xyz/core/contracts/interfaces/IInterchainGasPaymaster.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILiquidityLayerRouter {
    function dispatchWithTokens(
        uint32 _destinationDomain,
        bytes32 _recipientAddress,
        address _token,
        uint256 _amount,
        string calldata _bridge,
        bytes calldata _messageBody
    ) external returns (bytes32);
}

contract LiquidityRouter{

    event TokenSentWithMessage(bytes32 indexed messageId, uint32 indexed destDomain, address indexed recipientAddress, uint256 amount, string message);
    event TokenReceivedWithMessage(uint32 indexed origin, address indexed sender, string message, uint256 amount);
    address liquidityRouter;
    address interchainGasPaymaster;
    address USDCAddress;

    constructor(address _lrouter, address _igp, address _usdc){
        liquidityRouter = _lrouter;
        interchainGasPaymaster = _igp;
        USDCAddress = _usdc;
    }

    function send(uint32 _dest, address _recipient, uint256 _amount, string memory _message) payable external{
        IERC20(USDCAddress).transferFrom(msg.sender, address(this), _amount);
        IERC20(USDCAddress).approve(liquidityRouter, _amount);
        bytes32 messageId = ILiquidityLayerRouter(liquidityRouter).dispatchWithTokens(
            _dest,
            addressToBytes32(_recipient),
            USDCAddress,
            _amount,
            "Circle",
            abi.encode(_message)
        );
        uint256 quote = IInterchainGasPaymaster(interchainGasPaymaster).quoteGasPayment(_dest, 300000);
        IInterchainGasPaymaster(interchainGasPaymaster).payForGas{value: quote}(
            messageId,
            _dest,
            300000,
            msg.sender
        );
        emit TokenSentWithMessage(messageId, _dest, _recipient, _amount, _message);
    }

    function handleWithTokens(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message,
        address _token,
        uint256 _amount
    ) external{
        emit TokenReceivedWithMessage(_origin, bytes32ToAddress(_sender), abi.decode(_message, (string)), _amount);
    }



    // alignment preserving cast
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    // alignment preserving cast
    function bytes32ToAddress(bytes32 _buf) internal pure returns (address) {
        return address(uint160(uint256(_buf)));
    }

}