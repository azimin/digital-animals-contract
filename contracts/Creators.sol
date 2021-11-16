// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract Creators {
    address internal constant creator1 = 0x0000000000000000002000000000000000000000;
    address internal constant creator2 = 0x0000000000000000020200000000000000000000;
    address internal constant creator3 = 0x0000000000000000200020000000000000000000; 
    address internal constant creator4 = 0x0000000000000000200020000000000000000000;
    address internal constant creator5 = 0x0000000000000000200020000000000000000000;
    address internal constant creator6 = 0x0000000000000222000002220000000000000000;
    address internal constant creator7 = 0x0000000000002000000000002000000000000000;
    address internal constant creator8 = 0x0000000000002000000000002000000000000000;
    address internal constant creator9 = 0x0000000000000222222222220000000000000000;
    
    function isCreator(address operator) public pure virtual returns (bool) {
        return operator == creator1 ||
            operator == creator2 ||
            operator == creator3 ||
            operator == creator4 ||
            operator == creator5 ||
            operator == creator6 ||
            operator == creator7 ||
            operator == creator8 ||
            operator == creator9;
    }
}