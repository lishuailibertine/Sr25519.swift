//
//  Ed25519Error.swift
//  
//
//  Created by Yehor Popovych on 07.05.2021.
//

import Foundation

public enum Ed25519Error: Error, Equatable, Hashable {
    case randomGeneratorError(code: Int)
    case badSeedLength(length: Int, expected: Int)
    case badKeyPairLength(length: Int, expected: Int)
    case badChainCodeLength(length: Int, expected: Int)
    case badPublicKeyLength(length: Int, expected: Int)
    case badPrivateKeyLength(length: Int, expected: Int)
    case badSignatureLength(length: Int, expected: Int)
//    case badVrfSignatureLength(length: Int, expected: Int)
//    case badVrfOutputLength(length: Int, expected: Int)
//    case badVrfProofLength(length: Int, expected: Int)
//    case badVrfThresholdLength(length: Int, expected: Int)
//    case vrfError(code: UInt32)
}
