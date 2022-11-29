// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Test {
    address[] public routers;
    address[] public connectors;
    uint24 public constant poolFee = 3000;
    ISwapRouter swapRouter;
    struct SwapPath {
        bytes token;  
        bytes fee; 
    }
    
    //Converting a Number to a Binary Byte Array
    function  toBinaryString (uint n ) public payable returns (bytes memory){
        uint m = n;
        uint i = 0;
        while (m >0){
           i++; 
           m /= 2; 
        }
        bytes memory output = new bytes(i);
        while (n > 0){
          for(uint j = 0; j < i; j++)
            output[i-j] = (n % 2 == 1)? bytes1("1"): bytes1("0");  
          m /= 2;  
        }
       return (output); 
    } 

    //Array different connector combinations
    function setConnectorsMultiArray() internal returns (address[][] memory) {
        ERC20 paymentToken = ERC20(address(this)); 
        address[][] memory connectors_dbl = new address[][] (2**connectors.length);
        for(uint i = 0; i < 2**connectors.length; i++){
         paymentToken.approve(address(this), 1);    
         bytes memory b = toBinaryString(2**connectors.length + i);
         address[] memory conn = setConnectorsArray(b);
         connectors_dbl[i] = new address[](conn.length);
         for (uint j =0; j < conn.length; j++){
           connectors_dbl[i][j] = conn[j]; 
         }
        }
        return(connectors_dbl);
    }

    //Compiling an address string
    function setConnectorsArray(bytes memory b) internal view returns (address[] memory){
        uint i = 0;
        for (uint j = 0; j < b.length; j++)
          if (b[j] == "1") i++;
        address[] memory conn = new address[](i);
        i = 0;
        for (uint j = 0; j < b.length; j++){
            if (b[j] == "1"){
               conn[i] = connectors[j]; 
               i++;
            } 
        }
        return(conn);  
    }

    //Make a swap path
    function setSwopPath(address[] memory _connectors) internal view returns(SwapPath[] memory){
        SwapPath[] memory pathBytes = new SwapPath[](_connectors.length);
        for(uint i = 0; i < _connectors.length; i++){
            pathBytes[i+1].token = abi.encodePacked(connectors[i]);
            pathBytes[i+1].fee = abi.encodePacked(poolFee);
        }    
        return (pathBytes);  
    }

    function swapExactInputMultihop(uint256 amountIn, SwapPath[] memory pathBytes, address _router, address _tokenIn) public payable returns (uint256 amountOut) {
        // Transfer `amountIn` of _tokenIn to this contract.
        TransferHelper.safeTransferFrom(_tokenIn, msg.sender, address(this), amountIn);

        // Approve the router to spend _tokenIn.
        TransferHelper.safeApprove(_tokenIn, _router, amountIn);
         
        bytes memory path = new  bytes(pathBytes.length*2 - 1);
        uint j = 0;
        for (uint i = 0; i < pathBytes.length; i++){
           if (i ==  (pathBytes.length-1) ){
             path[j] = bytes1(pathBytes[i].token);
           }
           else{
             path[j] = bytes1(pathBytes[i].token);
             path[j] = bytes1(pathBytes[i].fee);
             j = j + 2;
           }
        } 

        // Multiple pool swaps are encoded through bytes called a `path`. A path is a sequence of token addresses and poolFees that define the pools used in the swaps.
        // The format for pool encoding is (tokenIn, fee, tokenOut/tokenIn, fee, tokenOut) where tokenIn/tokenOut parameter is the shared token across the pools.
        ISwapRouter.ExactInputParams memory params =
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(path),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0
            });

        // Executes the swap.
        amountOut = swapRouter.exactInput(params);
       return(amountOut);
    }

    /*
        Gets router* and path* that give max output amount with input amount and tokens
        @param amountIn input amount
        @param tokenIn source token
        @param tokenOut destination token
        @return max output amount and router and path, that give this output amount

        router* - Uniswap-like Router
        path* - token list to swap
     */
    function quote(
        uint amountIn,
        address tokenIn,
        address tokenOut
    ) external returns (uint amountOut, address router, address[] memory path) {
        ERC20 paymentToken = ERC20(address(this));
        amountOut = 0;
        address[][] memory connectors_dbl = setConnectorsMultiArray();
        for(uint i = 0; i < routers.length; i++){
          for(uint j = 0; j < connectors_dbl.length; j++){
           address[] memory path_connectors = new address[](connectors_dbl[j].length + 2);
           path_connectors[0] = tokenIn;
           for (uint k = 0; k < connectors_dbl[j].length; k++) 
             path_connectors[k+1] = connectors_dbl[j][k];
           path_connectors[path_connectors.length - 1] = tokenOut;   
           SwapPath[] memory pathBytes = setSwopPath(path_connectors);
           paymentToken.approve(address(this), 1); 
           uint amountCur = swapExactInputMultihop(amountIn, pathBytes, routers[i], path_connectors[0]);
           if (amountCur >= amountOut){
             amountOut = amountCur;
             router = routers[i];
             path = connectors_dbl[j];
           } 
          }  
        }
       return(amountOut, router, path); 
    }
    
    /*
        Swaps tokens on router with path, should check slippage
        @param amountIn input amount
        @param amountOutMin minumum output amount
        @param router Uniswap-like router to swap tokens on
        @param path tokens list to swap
        @return actual output amount
     */
    function swap(
        uint amountIn,
        uint amountOutMin,
        address router,
        address[] memory path
    ) external returns (uint amountOut) {
       ERC20 paymentToken = ERC20(address(this)); 
       SwapPath[] memory pathBytes = setSwopPath(path);
       paymentToken.approve(address(this), 1); 
       amountOut = swapExactInputMultihop(amountIn, pathBytes, router, path[0]);
      if (amountOut < amountOutMin) return (0);
      else return (amountOut); 
    }
}