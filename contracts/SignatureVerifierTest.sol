// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract SignatureVerifier {
    constructor() {}

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            // First 32 bytes stores the length of the signature

            // Add the signature offset to get the r part
            r := mload(add(sig, 32))
            // Add 32 bytes to the r part to get the s part
            s := mload(add(sig, 64))
            // Add 64 bytes to the r and s part to get the v part
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }

    function getSigner(
        bytes32 messageHash,
        bytes memory signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        // The message hash to be signed should be prefixed
        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        return ecrecover(prefixedHash, v, r, s);
    }
}
