// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Orchave {
    uint public constant verifierLockPrice = 0.1 ether;
    uint public constant verifierEarn = 0.001 ether;
    uint public constant verifierLockCommissionRatePercentage = 90;
    uint public constant dataPrice = 0.001 ether;

    address[] public verifiers;
    // (cid, merkleroot/hash)
    mapping(string => bytes32) public blockRewards;
    // (cid, hash)
    mapping(string => bytes32) private blocks;
    // (cid, merkleroot/hash)
    mapping(string => bytes32) private blockVerifiers;
    // (cid, verifier count)
    mapping(string => uint) public paidForVerification;

    // VERIFIER SECTION
    function joinVerifier() public payable {
        require(
            msg.value == verifierLockPrice,
            "The value you send is not enough to be a verifier"
        );
        for (uint i = 0; i < verifiers.length; i++)
            if (verifiers[i] == msg.sender)
                revert("This address is already verifier");

        verifiers.push(msg.sender);
    }

    function leaveVerifier() public payable {
        // Remove the msg.sender
        for (uint256 i = 0; i < verifiers.length; i++)
            if (verifiers[i] == msg.sender) {
                verifiers[i] = verifiers[verifiers.length - 1];
                verifiers.pop();
                break;
            }

        uint amount = (verifierLockPrice *
            verifierLockCommissionRatePercentage) / 100;
        payable(msg.sender).transfer(amount);
    }

    function askForVerification(
        string memory cid,
        uint verifierCount
    ) public payable {
        require(
            verifierEarn * verifierCount == msg.value,
            "ETH you sent is not enough for verifiers to verify"
        );
        paidForVerification[cid] += verifierCount;
    }

    function settleVerification(
        string memory cid,
        bytes32 hash,
        bytes[] memory signatureList
    ) public {
        require(paidForVerification[cid] != 0, "This is not provided data");
        bytes[] memory signatureSet = arrayToSet(signatureList);
        bytes[] memory validSignatures;
        bytes32[] memory signatureListPublicKey = new bytes32[](
            signatureList.length
        );

        for (uint i = 0; i < signatureSet.length; i++) {
            // yanlış olurse error ver, signatureListPublicKey her zaman tamamen dolu olsun
            if (
                checkVerifierExists(
                    getSigner(hash, abi.encodePacked(signatureSet[i]))
                )
            ) {
                // validSignatures[validCount] = signatureSet[i];
                // validCount ++;
                revert("Some of Signatures is not true");
            }
        }
        bytes32 merkleRoot = createRoot(signatureListPublicKey);

        if (paidForVerification[cid] >= validSignatures.length) {
            blocks[cid] = hash;
            blockVerifiers[cid] = merkleRoot;
            blockRewards[cid] = merkleRoot;
            paidForVerification[cid] -= validSignatures.length;
        }
    }

    function askForBlockHash(
        string memory cid
    ) public payable returns (bytes32) {
        require(msg.value == dataPrice, "Not enough eth");
        return blocks[cid];
    }

    function createRoot(bytes32[] memory array) public pure returns (bytes32) {
        require(array.length > 0, "Array must not be empty");

        // Recursively build the Merkle tree and return the root
        return _createRoot(array);
    }

    function _createRoot(
        bytes32[] memory array
    ) private pure returns (bytes32) {
        // Base case: if there's only one hash left, return it
        if (array.length == 1) return array[0];

        bytes32[] memory arrayLeft = new bytes32[](array.length / 2);
        bytes32[] memory arrayRight = new bytes32[](array.length / 2);

        for (uint i = 0; i < array.length / 2; i++) {
            arrayLeft[i] = array[i];
        }
        for (uint i = array.length / 2; i < array.length; i++) {
            arrayRight[i] = array[i];
        }

        return
            sha256(abi.encode(_createRoot(arrayLeft), _createRoot(arrayRight)));
    }

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

    function checkVerifierExists(
        address verifierAddress
    ) internal view returns (bool) {
        for (uint i = 0; i < verifiers.length; i++) {
            if (verifiers[i] == verifierAddress) {
                return true;
            }
        }
        return false;
    }

    function arrayToSet(
        bytes[] memory array
    ) public pure returns (bytes[] memory) {
        bytes[] memory tempArray = new bytes[](array.length);
        uint256 uniqueCount = 0;

        // İlk geçiş: eşsiz elemanları belirle ve say
        for (uint256 i = 0; i < array.length; i++) {
            bool isUnique = true;
            for (uint256 j = 0; j < i; j++) {
                if (keccak256(array[i]) == keccak256(array[j])) {
                    // bytes karşılaştırması
                    isUnique = false;
                    break;
                }
            }
            if (isUnique) {
                tempArray[uniqueCount] = array[i];
                uniqueCount++;
            }
        }

        // Eşsiz elemanlar için doğru boyutta yeni bir array oluştur
        bytes[] memory uniqueArray = new bytes[](uniqueCount);

        // Eşsiz elemanları yeni array'e kopyala
        for (uint256 i = 0; i < uniqueCount; i++) {
            uniqueArray[i] = tempArray[i];
        }

        return uniqueArray;
    }
}
