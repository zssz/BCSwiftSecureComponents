# Secure Components - Definitions

**Authors:** Wolf McNally, Christopher Allen, Blockchain Commons</br>
**Revised:** Aug 26, 2022</br>
**Status:** DRAFT

---

## Contents

* [Envelope Introduction](00-INTRODUCTION.md)
* [Types](01-TYPES.md)
* [Envelope Overview](02-ENVELOPE.md)
* [Envelope Notation](03-ENVELOPE-NOTATION.md)
* [Output Formats](04-OUTPUT-FORMATS.md)
* [Envelope Expressions](05-ENVELOPE-EXPRESSIONS.md)
* Definitions: This document
* [Examples](07-EXAMPLES.md)
* [Noncorrelation](08-NONCORRELATION.md)
* [Elision and Redaction](09-ELISION-REDACTION.md)
* [Existence Proofs](10-EXISTENCE-PROOFS.md)
* [Appendix A: MVA Algorithm Suite](11-A-ALGORITHMS.md)
* [Appendix B: Envelope Test Vectors](12-B-ENVELOPE-TEST-VECTORS.md)
* [Appendix C: Envelope SSKR Test Vectors](13-C-ENVELOPE-SSKR-TEST-VECTORS.md)

---

## Sections of this Document

* [AgreementPrivateKey](#agreementprivatekey)
* [AgreementPublicKey](#agreementpublickey)
* [CID](#cid)
* [Digest](#digest)
* [Envelope](#envelope)
* [EncryptedMessage](#encryptedmessage)
* [Nonce](#nonce)
* [Password](#password)
* [PrivateKeyBase](#privatekeybase)
* [PublicKeyBase](#publickeybase)
* [Salt](#salt)
* [SealedMessage](#sealedmessage)
* [Signature](#signature)
* [SigningPrivateKey](#signingprivatekey)
* [SigningPublicKey](#signingpublickey)
* [SymmetricKey](#symmetrickey)

---

## Introduction

This section describes each component, and provides its CDDL definition for CBOR serialization.

---

## AgreementPrivateKey

A Curve25519 private key used for [X25519 key agreement](https://datatracker.ietf.org/doc/html/rfc7748).

### AgreementPrivateKey: Swift Definition

```swift
struct AgreementPrivateKey {
    let data: Data
}
```

### AgreementPrivateKey: CDDL

|CBOR Tag|Swift Type|
|---|---|
|702|`AgreementPrivateKey`|

```
agreement-private-key = #6.702(key)

key = bytes .size 32
```

---

## AgreementPublicKey

A Curve25519 public key used for [X25519 key agreement](https://datatracker.ietf.org/doc/html/rfc7748).

### AgreementPublicKey: Swift Definition

```swift
struct AgreementPublicKey {
    let data: Data
}
```

### AgreementPublicKey: CDDL

|CBOR Tag|Swift Type|
|---|---|
|230|`AgreementPublicKey`|

```
agreement-public-key = #6.62(key)

key = bytes .size 230
```

---

## CID

A Common Identifier (CID) is a unique 32-byte identifier that, unlike a `Digest` refers to an object or set of objects that may change depending on who resolves the `CID` or when it is resolved. In other words, the referent of a `CID` may be considered mutable.

### CID: Swift Defintion

```swift
struct CID {
    let data: Data
}
```

### CID: CDDL

```
cid = #6.202(cid-data)

cid-data = bytes .size 32
```

---

## Digest

A Digest is a cryptographic hash of some source data. Currently Secure Components specifies the use of [BLAKE3](https://github.com/BLAKE3-team/BLAKE3-specs/blob/master/blake3.pdf), but more algorithms may be supported in the future.

|CBOR Tag|Swift Type|
|---|---|
|203|`Digest`|

### Digest: CDDL

```
digest = #6.203(blake3-digest)

blake3-digest = bytes .size 32
```

---

## Envelope

Please see [here](02-ENVELOPE.md) for a full description.

### Envelope: Swift Definition

An Envelope consists of a `subject` and a list of zero or more `assertion`s. Here is its notional definition in Swift:

```swift
struct Envelope {
    let subject: Subject
    let assertions: [Assertion]
}

struct Assertion {
    let predicate: Envelope
    let object: Envelope
}
```

The *actual* definition of `Envelope` is an enumerated type. Every case stores a precalculated `Digest` as part of its associated data, either directly or within its other objects:

```swift
public indirect enum Envelope: DigestProvider {
    case node(subject: Envelope, assertions: [Envelope], digest: Digest)
    case leaf(CBOR, Digest)
    case wrapped(Envelope, Digest)
    case knownValue(KnownValue, Digest)
    case assertion(Assertion)
    case encrypted(EncryptedMessage)
    case elided(Digest)
}

public struct Assertion: DigestProvider {
    public let predicate: Envelope
    public let object: Envelope
    public let digest: Digest
}
```

The cases of `Envelope` are as follows. Except for `.node`, each case represents a "bare subject," i.e., a subject with no assertions. When a subject has at least one assertion, it is wrapped in a `.node` case.

* `.node` A subject with one or more assertions.
* `.leaf` A terminal CBOR object.
* `.wrapped` An enclosed `Envelope`.
* `.knownValue` An integer tagged as a predicate and typically used in the `predicate` position of an assertion.
* `.assertion` A (predicate, object) pair.
* `.encrypted` A subject that has been encrypted.
* `.elided` A subject that has been elided.

### Envelope: CDDL

|Tag|Type|
|---|---|
|200|`envelope`|
|220|`leaf`|
|221|`assertion`|
|223|`knownValue`|
|224|`wrappedEnvelope`|

```
envelope = #6.200(
    envelope-content
)

envelope-content = (
    node /
    leaf /
    wrapped-envelope /
    known-value /
    assertion /
    encrypted /
    elided
)

node = [envelope-content, + assertion-element]

assertion-element = ( assertion / encrypted / elided )

leaf = #6.24(bytes) ; See https://www.rfc-editor.org/rfc/rfc8949.html#name-encoded-cbor-data-item

wrapped-envelope = #6.224(envelope-content)

known-value = #6.223(uint)

assertion = #6.221([envelope, envelope])

encrypted = crypto-msg

elided = digest
```

---

## EncryptedMessage

`EncryptedMessage` is a symmetrically-encrypted message and is specified in full in [BCR-2022-001](https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2022-001-secure-message.md).

When used as part of Secure Components, and particularly with `Envelope`, the `aad` field contains the `Digest` of the encrypted plaintext. If non-correlation is necessary, then add random salt to the plaintext before encrypting.

### EncryptedMessage: Swift Definition

```swift
struct EncryptedMessage {
    let cipherText: Data
    let aad: Data
    let nonce: Data
    let auth: Data
}
```

### EncryptedMessage: CDDL

|CBOR Tag|UR Type|Swift Type|
|---|---|---|
|201|`crypto-msg`|`EncryptedMessage`|

A `crypto-msg` is an array containing either 3 or 4 elements. If additional authenticated data `aad` is non-empty, it is included as the fourth element, and omitted otherwise. `aad` MUST NOT be present and non-empty.

```
crypto-msg = #6.201([ ciphertext, nonce, auth, ? aad ])

ciphertext = bytes       ; encrypted using ChaCha20
aad = bytes              ; Additional Authenticated Data
nonce = bytes .size 12   ; Random, generated at encryption-time
auth = bytes .size 16    ; Authentication tag created by Poly1305
```

---

## Nonce

A `Nonce` is a cryptographically strong random "number used once" and is frequently used in algorithms where a random value is needed that should never be reused. Secure Components uses 12-byte nonces.

```swift
struct Nonce {
    let data: Data
}
```

## Nonce: CDDL

```
nonce = #6.707(bytes .size 12)
```

---

## Password

`Password` is a password that has been salted and hashed using [scrypt](https://datatracker.ietf.org/doc/html/rfc7914), and is thereofore suitable for storage and use for authenticating users via password. To validate an entered password, the same hashing algorithm using the same parameters and salt must be performed again, and the hashes compared to determine validity. This way the authenticator never needs to store the password. The processor and memory intensive design of the scrypt algorithm makes such hashes resistant to brute-force attacks.

### Password: Swift Definition

```swift
struct Password {
    let n: Int
    let r: Int
    let p: Int
    let salt: Data
    let data: Data
}
```

### Password: CDDL

|CBOR Tag|Swift Type|
|---|---|
|700|`Password`|

```
password = #6.700([n, r, p, salt, hashed-password])

n = uint                             ; iterations
r = uint                             ; block size
p = uint                             ; parallelism factor
salt = bytes                         ; random salt (16 bytes recommended)
hashed-password = bytes              ; 32 bytes recommended
```

---

## PrivateKeyBase

`PrivateKeyBase` holds key material such as a Seed belonging to an identifiable entity, or an HDKey derived from a Seed. It can produce all the private and public keys needed to use this suite. It is usually only serialized for purposes of backup.

|CBOR Tag|UR Type|Swift Type|
|---|---|---|
|205|`crypto-prvkeys`|`PrivateKeyBase`|

### PrivateKeyBase: Swift Definition

```swift
struct PrivateKeyBase {
    data: Data
}
```

### PrivateKeyBase: CDDL

```
crypto-prvkeys = #6.205([key-material])

key-material = bytes
```

### Derivations

* `SigningPrivateKey`: [BLAKE3](https://github.com/BLAKE3-team/BLAKE3-specs/blob/master/blake3.pdf) with context: `signing`.
* `AgreementPrivateKey`: [BLAKE3](https://github.com/BLAKE3-team/BLAKE3-specs/blob/master/blake3.pdf) with context: `agreement`.
* `SigningPublicKey`: [BIP-340 Schnorr](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) x-only public key or [ECDSA-25519-doublesha256](https://en.bitcoin.it/wiki/BIP_0137) public key.
* `SigningPrivateKey`: [RFC-7748 X25519](https://datatracker.ietf.org/doc/html/rfc7748).

---

## PublicKeyBase

`PublicKeyBase` holds the public keys of an identifiable entity, and can be made public. It is not simply called a "public key" because it holds at least _two_ public keys: one for signing and another for encryption. The `SigningPublicKey` may specifically be for verifying Schnorr or ECDSA signatures.

### PublicKeyBase: Swift Definition

```swift
struct PublicKeyBase {
    let signingPublicKey: SigningPublicKey
    let agreementPublicKey: AgreementPublicKey
}
```

### PublicKeyBase: CDDL

|CBOR Tag|UR Type|Swift Type|
|---|---|---|
|206|`crypto-pubkeys`|`PublicKeyBase`|

A `crypto-pubkeys` is a two-element array with the first element being the `signing-public-key` and the second being the `agreement-public-key`.

```
crypto-pubkeys = #6.206([signing-public-key, agreement-public-key])
```

---

## Salt

A `Salt` is random data frequently used as an additional input to one-way algorithms (e.g., password hashing) where similar inputs (the same password) should not yield the same outputs (the hashed password.) Salts are not usually secret.

```swift
struct Salt {
    let data: Data
}
```

## Salt: CDDL

```
salt = #6.708(bytes)
```

---

## SealedMessage

`SealedMessage` is a message that has been one-way encrypted to a particular `PublicKeyBase`, and is used to implement multi-recipient public key encryption using `Envelope`. The sender of the message is generated at encryption time, and the ephemeral sender's public key is included, enabling the receipient to decrypt the message without identifying the real sender.

### SealedMessage: Swift Definition

```swift
struct SealedMessage {
    let message: EncryptedMessage
    let ephemeralPublicKey: AgreementPublicKey
}
```

### SealedMessage: CDDL

|CBOR Tag|UR Type|Swift Type|
|---|---|---|
|207|`crypto-sealed`|`SealedMessage`|

```
crypto-sealed = #6.207([crypto-message, ephemeral-public-key])

ephemeral-public-key = agreement-public-key
```

---

## Signature

A cryptographic signature. It has two variants:

* A [BIP-340 Schnorr](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) signature.
* An ECDSA signature [ECDSA-25519-doublesha256](https://en.bitcoin.it/wiki/BIP_0137) signatures.

### Signature: Swift Definition

```swift
public enum Signature {
    case schnorr(data: Data, tag: Data)
    case ecdsa(data: Data)
}
```

### Signature: CDDL

|CBOR Tag|Swift Type|
|---|---|
|222|`Signature`|

A `signature` has two variants. The Schnorr variant is preferred. Schnorr signatures may include tag data of arbitrary length.

If the `signature-variant-schnorr` is selected and has no tag, it will appear directly as a byte string of length 64. If it includes tag data, it will appear as a two-element array where the first element is the signature and the second element is the tag. The second form MUST NOT be used if the tag data is empty.

If the `signature-variant-ecdsa` is selected, it will appear as a two-element array where the first element is `1` and the second element is a byte string of length 64.

```
signature = #6.222([ signature-variant-schnorr / signature-variant-ecdsa ])

signature-variant-schnorr = signature-schnorr / signature-schnorr-tagged
signature-schnorr = bytes .size 64
signature-schnorr-tagged = [signature-schnorr, schnorr-tag]
schnorr-tag = bytes .size ne 0

signature-variant-ecdsa = [ 1, signature-ecdsa ]
signature-ecdsa = bytes .size 64
```

---

## SigningPrivateKey

A private key for creating [BIP-340 Schnorr](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) or [ECDSA-25519-doublesha256](https://en.bitcoin.it/wiki/BIP_0137) signatures.

### SigningPrivateKey: Swift Definition

```swift
struct SigningPrivateKey {
    let data: Data
}
```

### SigningPrivateKey: CDDL

|CBOR Tag|Swift Type|
|---|---|
|704|`SigningPrivateKey`|

```
private-signing-key = #6.704(key)

key = bytes .size 32
```

---

## SigningPublicKey

A public key for verifying signatures. It has two variants:

* An x-only public key for verifying [BIP-340 Schnorr](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki) signatures.
* An ECDSA public key [ECDSA-25519-doublesha256](https://en.bitcoin.it/wiki/BIP_0137) signatures.

### SigningPublicKey: Swift Definition

```swift
public enum SigningPublicKey {
    case schnorr(ECXOnlyPublicKey)
    case ecdsa(ECPublicKey)
}
```

### SigningPublicKey: CDDL

|CBOR Tag|Swift Type|
|---|---|
|705|`SigningPublicKey`|

A signing public key has two variants: Schnorr or ECDSA. The Schnorr variant is preferred, so it appears as a byte string of length 32. If ECDSA is selected, it appears as a 2-element array where the first element is `1` and the second element is the compressed ECDSA key as a byte string of length 33.

```
signing-public-key = #6.705(key-variant-schnorr / key-variant-ecdsa)

key-variant-schnorr = key-schnorr
key-schnorr = bytes .size 32

key-variant-ecdsa = [1, key-ecdsa]
key-ecdsa = bytes .size 33
```

---

## SymmetricKey

A symmetric key for encryption and decryption of [IETF-ChaCha20-Poly1305](https://datatracker.ietf.org/doc/html/rfc8439) messages.

### SymmetricKey: Swift Definition

```swift
public struct SymmetricKey {
    let data: Data
}
```

### SymmetricKey: CDDL

|CBOR Tag|Swift Type|
|---|---|
|204|`SymmetricKey`|

```
symmetric-key = #6.204( symmetric-key-data )
symmetric-key-data = bytes .size 32
```
