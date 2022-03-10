//
//  KeyPair.swift
//  
//
//  Created by Yehor Popovych on 07.05.2021.
//

import Foundation
#if !COCOAPODS
import CSr25519
import Sr25519Helpers
#endif
import UncommonCrypto

public struct Ed25519KeyPair {
    private let _private: ed25519_secret_key
    private let _public: Ed25519PublicKey
    
    public init(seed: Ed25519Seed) {
        self.init(secret: try! TCArray.new(raw: seed.seed))
    }
    
    public init(raw: Data) throws {
        guard raw.count == Self.size else {
            throw Ed25519Error.badKeyPairLength(
                length: raw.count, expected: Self.size
            )
        }
        _private = try! TCArray.new(raw: Data(raw[0..<Self.secretSize]))
        _public = Ed25519PublicKey(key: try! TCArray.new(raw: Data(raw[Self.secretSize..<Self.size])) )
    }
    
    public init(rawSk: Data) throws {
        guard rawSk.count == Self.secretSize else {
            throw Ed25519Error.badPrivateKeyLength(
                length: rawSk.count, expected: Self.size
            )
        }
        self.init(secret: try! TCArray.new(raw: rawSk))
    }
    
    init(secret: ed25519_secret_key) {
        _private = secret
        var pub: ed25519_public_key = TCArray.new()
        TCArray
            .pointer(of: (UInt8.self, UInt8.self))
            .wrap(&pub, secret) { pub, priv in
                ed25519_publickey(priv.baseAddress, pub.baseAddress)
            }
        _public = Ed25519PublicKey(key: pub)
    }
    
    public var publicKey: Ed25519PublicKey { _public }
    
    public var raw: Data { TCArray.get(raw: _private) + TCArray.get(raw: _public.key) }
    public var privateRaw: Data { TCArray.get(raw: _private) }
    
    public func sign(message: Data) -> Ed25519Signature {
        var out: ed25519_signature = TCArray.new()
        TCArray
            .pointer(of: (UInt8.self, UInt8.self, UInt8.self))
            .wrap(&out, _private, _public.key) { sp, privp, pubp in
                message.withUnsafeBytes { mes in
                    let message = mes.bindMemory(to: UInt8.self)
                    ed25519_sign(message.baseAddress, message.count,
                                 privp.baseAddress, pubp.baseAddress,
                                 sp.baseAddress)
                }
            }
        return Ed25519Signature(signature: out)
    }
    
    public func verify(message: Data, signature: Ed25519Signature) -> Bool {
        _public.verify(message: message, signature: signature)
    }
    
    public static let size: Int = secretSize + MemoryLayout<ed25519_public_key>.size
    public static let secretSize: Int = MemoryLayout<ed25519_secret_key>.size
}

extension Ed25519KeyPair: Equatable {
    public static func == (lhs: Ed25519KeyPair, rhs: Ed25519KeyPair) -> Bool {
        TCArray.equal(lhs._private, rhs._private) && lhs._public == rhs._public
    }
}

extension Ed25519KeyPair: Hashable {
    public func hash(into hasher: inout Hasher) {
        TCArray.hash(_private, in: &hasher)
        hasher.combine(_public)
    }
}

extension Ed25519KeyPair {
    public static func deriveKey(path: String, seed: Data) -> (key: Data, chainCode: Data) {
        let masterKeyData = Data(HMAC.authenticate(type: .sha512, key: [UInt8]("ed25519 seed".utf8), data: seed))
        
        let key = masterKeyData.subdata(in:0..<32)
        let chainCode = masterKeyData.subdata(in:32..<64)
        
        return deriveKey(path: path, key: key, chainCode: chainCode)
    }
    
    public static func deriveKey(path: String, key: Data, chainCode: Data) -> (key: Data, chainCode: Data) {
        let paths = path.components(separatedBy: "/")

        var newKey = key
        var newChainCode = chainCode
        
        for path in paths {
            if path == "m" {
                continue
            }
            var hpath:UInt32 = 0
            if path.contains("'") {
                let pathnum = UInt32(path.replacingOccurrences(of: "'", with: "")) ?? 0
                hpath = pathnum + 0x80000000
            } else {
                hpath = UInt32(path) ?? 0
            }
            let pathData32 = UInt32(hpath)
            let pathDataBE = withUnsafeBytes(of: pathData32.bigEndian, Array.init)
            var data = Data()
            data.append([0], count: 1)
            data.append(newKey)
            data.append(pathDataBE,count: 4)
            
            let d = Data(HMAC.authenticate(type: .sha512, key: Array(newChainCode), data: data))
            newKey = d.subdata(in: 0..<32)
            newChainCode = d.subdata(in:32..<64)
        }
        return (newKey, newChainCode)
    }
}
