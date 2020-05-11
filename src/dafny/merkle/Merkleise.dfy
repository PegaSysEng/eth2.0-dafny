/*
 * Copyright 2020 ConsenSys AG.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may 
 * not use this file except in compliance with the License. You may obtain 
 * a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software dis-
 * tributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
 * License for the specific language governing permissions and limitations 
 * under the License.
 */

include "../utils/NativeTypes.dfy"
include "../utils/Eth2Types.dfy"
include "../utils/Helpers.dfy"
include "../utils/MathHelpers.dfy"
include "../ssz/Constants.dfy"
include "../ssz/Serialise.dfy"
include "../ssz/IntSeDes.dfy"
include "../ssz/BoolSeDes.dfy"
include "../ssz/BitListSeDes.dfy"
include "../ssz/BytesAndBits.dfy"

/**
 *  SSZ_Merkleise library.
 *
 *  Primary reference: simple-serialize.md
 *  Secondary reference: py-ssz implementation
 *
 *  This library defines various helper functions for merkleisation, including 
 *  chunk_count, bitfield_bytes, pack, merkleise*, mix_in_length, mix_in_type.
 *
 *  Other helper functions (size_of and next_pow_of_two) are included in other
 *  libraries.
 *
 *  The get_hash_tree_root function is also included in this library.
 */
 module SSZ_Merkleise {

    import opened NativeTypes
    import opened Eth2Types
    import opened Constants
    import opened IntSeDes
    import opened BoolSeDes
    import opened BitListSeDes
    import opened BytesAndBits
    import opened SSZ
    import opened Helpers
    import opened MathHelpers

    /** chunkCount.
     *
     *  @param  s   A serialisable object.
     *  @returns    Calculate the amount of leafs for merkleisation of the type.
     *
     *  @note       For composite types and containers, a helper function may be required
     *              to complete the calculation?
     *  @note       A leaf is 256 bits/32-bytes.
     *  @note       The maximum tree depth for a depost contract is 32 
     *              (reference: Phase 0 spec - deposit contract).
     */
    function method chunkCount(s: Serialisable): nat
        ensures 0 <= chunkCount(s) // add upper limit ???
    {
        match s
            case Bool(b) => chunkCountBool(b)
            case Uint8(n) => chunkCountUint8(n)
            case Bitlist(xl) => chunkCountBitlist(xl) 
            case Bytes32(bs) => chunkCountBytes32(bs)
    } 

    /** 
     * chunkCount helper functions for specific types
     */
    function method chunkCountBool(b: bool): nat
        // all basic types require 1 leaf (reference: simple-serialize.md)
        ensures chunkCountBool(b) == 1
        ensures |pack(Bool(b))| == chunkCountBool(b)
    {
        1
    }

    function method chunkCountUint8(n: uint8): nat
        // all basic types require 1 leaf (reference: simple-serialize.md)
        ensures chunkCountUint8(n) == 1
        ensures |pack(Uint8(n))| == chunkCountUint8(n)
    {
        1
    }

    function method chunkCountBitlist(xl: seq<bool>): nat
        // divide by chunk size (in bits), rounding up (reference: simple-serialize.md)
        // the spec doesn't make reference to whether N can be zero for bitlist[N]
        // the py-szz implementation of bitlists only raises an error if N is negative
        // hence it will be assumed that N >= 0
        ensures 0 <= chunkCountBitlist(xl) == ceil(|xl|, BITS_PER_CHUNK)
        //ensures |bitfieldBytes(xl)| == chunkCountBitlist(xl) (moved to lemma)
    {
        (|xl|+BITS_PER_CHUNK-1)/BITS_PER_CHUNK
    }

    lemma lengthBitfieldBytes(xl: seq<bool>)
        ensures |bitfieldBytes(xl)| == chunkCountBitlist(xl)
    {
            if (|xl| == 0) {
                calc == {
                    // |bitfieldBytes(xl)|;
                    // == 
                    // |[]|;
                    // ==
                    // 0;
                    // ==
                    // chunkCountBitlist(xl);
                }
            } else {
                calc == {
                    |bitfieldBytes(xl)|;
                    ==
                    |toChunks(fromBitsToBytes(xl)) |;
                    //|toChunks(serialiseObjects(s))|;
                    ==
                    {toChunksProp2(fromBitsToBytes(xl));} ceil(|fromBitsToBytes(xl)|, BYTES_PER_CHUNK);
                    ==
                    ceil(|xl|, BITS_PER_CHUNK);
                    ==
                    chunkCountBitlist(xl);
                }
            }
        }

    function method chunkCountBytes32(bs: Seq32Byte): nat
        ensures chunkCountBytes32(bs) == ceil(|bs|, BYTES_PER_CHUNK)
        //ensures pack
    {
        var s := default(Uint8_);
        (|bs| * sizeOf(s) + 31) / BYTES_PER_CHUNK
    }

    

    /** 
     *  Predicate used in checking chunk properties.
     */
    predicate is32BytesChunk(c : chunk) 
    // test whether a chunk has 32 (BYTES_PER_CHUNK) chunks
    {
        |c| == BYTES_PER_CHUNK
    }

    // TODO: MOVE TO ETH2 TYPES
     // i.e. the output of serialisation
    //type serialisedElement = seq<Byte> // i.e. the output of serialisation
    // bounds? should be at least 1 byte (if representing serialised output)
    // maybe call serialisedBytes or serialisedElement?
    
    const EMPTY_CHUNK := timeSeq<Byte>(0,32)
    //[0 as Byte, 0 as Byte, 0 as Byte, 0 as Byte, 
    //                         0 as Byte,0 as Byte,0 as Byte,0 as Byte, 
    //                         0 as Byte,0 as Byte,0 as Byte,0 as Byte, 
    //                         0 as Byte,0 as Byte,0 as Byte,0 as Byte, 
    //                         0 as Byte,0 as Byte,0 as Byte,0 as Byte,
    //                         0 as Byte,0 as Byte,0 as Byte,0 as Byte,
    //                         0 as Byte,0 as Byte,0 as Byte,0 as Byte, 
    //                         0 as Byte,0 as Byte,0 as Byte,0 as Byte]

    /** 
     *  Properties of empty chunk.
     */
    lemma emptyChunkIs32BytesOfZeros()
        ensures is32BytesChunk(EMPTY_CHUNK) 
        ensures forall i :: 0 <= i < |EMPTY_CHUNK| ==> EMPTY_CHUNK[i]== 0 //as Byte 
    {   //  Thanks Dafny
    }

    /** rightPadZeros.
     *
     *  @param  b   A sequence of bytes.
     *  @returns    The sequence of bytes right padded with zero bytes to form a 32-byte chunk.
     *
     */
    function method rightPadZeros(b: bytes): chunk
        requires |b| < BYTES_PER_CHUNK
        ensures is32BytesChunk(rightPadZeros(b)) 
    {
        b + EMPTY_CHUNK[|b|..]
    }

    /** toChunks.
     *
     *  @param  b   A sequence of bytes i.e. a Bytes object.
     *  @returns    A sequence of 32-byte chunks, right padded with zero bytes if b % 32 != 0 
     *
     *  @note       This version of toChunks is suggested as an alternative to the in py-ssz,
     *              as this version ensures that even if |b| == 0 an EMPTY CHUNK will still 
     *              be returned. It also satisfies the toChunksProp1 and toChunksProp2 lemmas.
     *
     */
    function method toChunks(b: bytes): seq<chunk>
        ensures |toChunks(b)| > 0
        ensures forall i :: 0 <= i < |toChunks(b)| ==> is32BytesChunk(toChunks(b)[i]) 
        decreases b
    {
        if |b| < BYTES_PER_CHUNK then [rightPadZeros(b)]
        else    if |b| == BYTES_PER_CHUNK then [b] 
                else [b[..BYTES_PER_CHUNK]] + toChunks(b[BYTES_PER_CHUNK..])
    }    


    /** toChunks (py-ssz version).
     *
     *  @param  b   A sequence of bytes i.e. a Bytes object.
     *  @returns    A sequence of 32-byte chunks, right padded with zero bytes if b % 32 != 0 
     *
     *  @note       The py-ssz implementation can result in a 0 chunk output (empty seq)
     *              and therefore 
     *              doesn't satisfy the toChunksProp1 and toChunksProp2 lemmas. It also causes
     *              an error in the Pack function, which should reutrn at least one chunk.
     */
    // function toChunks(b: Bytes): seq<chunk>
    //     //ensures |toChunks(b)| > 0
    // {
    //     var full_chunks := |b| / BYTES_PER_CHUNK;
    //     if |b| == 0 then []
    //     else if |b| % BYTES_PER_CHUNK == 0 then [b[..32]] + toChunks(b[32..])
    //         else toChunks(b[..(full_chunks*BYTES_PER_CHUNK)]) + [rightPadZeros(b[(full_chunks*BYTES_PER_CHUNK)..])]
    // }   
    
    /** 
     *  Properties of chunk.
     */
    lemma {:induction b} toChunksProp1(b: bytes)
        requires |b| == 0
        ensures |toChunks(b)| == 1
    {
    }

    lemma  {:induction b} toChunksProp2(b: bytes)
        requires |b| > 0
        ensures 1 <= |toChunks(b)| == ceil(|b|, 32) 
    {
    }

    /** Pack.
     *
     *  @param  s   A sequence of serialised objects (seq<Byte>).
     *  @returns    A sequence of 32-byte chunks, the final chunk is right padded with zero 
     *              bytes if necessary. It is implied by the spec that at least one chunk is 
     *              returned (see note below).
     *
     *  @note       The pack function isn't type based.
     *  @note       The spec (eth2.0-specs/ssz/simple-serialize.md) says 'Given ordered objects 
     *              of the same basic type, serialize them, pack them into BYTES_PER_CHUNK-byte 
     *              chunks, right-pad the last chunk with zero bytes, and return the chunks.'
     *  @note       The py-ssz implementation checks for |seq<Bytes>| == 0 for which it returns
     *              the EMPTY_CHUNK. However, if the length of the input is greater than 0, i.e.
     *              |seq<Bytes>| > 0, a toChunks function is called and the toChunks function in
     *              the py-ssz implementation can return an empty seq and therefore a zero
     *              chunk output.           
     */
     // Applicable to uintN, bool, or list/vector of uintN
     // Can't be a list/vector of bool's as bitlists/bitvectors are dealth with separately
     // Treat uint or bool as sequence of length 1 e.g. call pack([uint8])

    //  function pack(s: seq<Serialisable>) : seq<chunk>
    //     requires forall i :: 0 <= i < |s| ==> typeOf(s[i]) in {Uint8_, Bool_}
    //     requires forall i :: 1 <= i < |s| ==> typeOf(s[i]) in {Uint8_}
    //     requires forall i,j :: 0 <= i < j < |s| ==> typeOf(s[i]) == typeOf(s[j])
    //     // no upper bound on length of any individual serialised element???
    //     ensures forall i :: 0 <= i < |pack(s)| ==> is32BytesChunk(pack(s)[i])
    //     ensures 1 <= |pack(s)| 
    // {        
    //     if |s| == 0 then [EMPTY_CHUNK] // can theoretically have list[uint8, 0]
    //     // else toChunks(concatSerialisedElements(s))  
    //     else toChunks(serialiseObjects(s))
    // }
    function method pack(s: Serialisable): seq<chunk>
        requires typeOf(s) in {Bool_, Uint8_, Bytes32_}
    {
        match s
            case Bool(b) => packBool(b)
            case Uint8(n) => packUint8(n)
            case Bytes32(bs) => packBytes32(bs)
    } 

    /** 
     * pack functions for specific types
     */
    function method packBool(b: bool): seq<chunk>
        ensures |packBool(b)| == 1
    {
        toChunks(serialise(Bool(b)))
    }

    function method packUint8(n: uint8): seq<chunk>
        ensures |packUint8(n)| == 1
    {
        toChunks(serialise(Uint8(n)))
    }

    function method packBytes32(bs: Seq32Byte): seq<chunk>
        ensures |packBytes32(bs)| == 1
    {
        toChunks(serialise(Bytes32(bs)))
    }

    /** Pack.
     *
     *  @param  s   A sequence of serialised objects (seq<Byte>).
     *  @returns    A sequence of 32-byte chunks, the final chunk is right padded with zero 
     *              bytes if necessary. It is implied by the spec that at least one chunk is 
     *              returned (see note below).
     *
     *  @note       The pack function isn't type based.
     *  @note       The spec (eth2.0-specs/ssz/simple-serialize.md) says 'Given ordered objects 
     *              of the same basic type, serialize them, pack them into BYTES_PER_CHUNK-byte 
     *              chunks, right-pad the last chunk with zero bytes, and return the chunks.'
     *  @note       The py-ssz implementation checks for |seq<Bytes>| == 0 for which it returns
     *              the EMPTY_CHUNK. However, if the length of the input is greater than 0, i.e.
     *              |seq<Bytes>| > 0, a toChunks function is called and the toChunks function in
     *              the py-ssz implementation can return an empty seq and therefore a zero
     *              chunk output.           
     */
    // Applicable to uintN, bool, or list/vector of uintN
    // Can't be a list/vector of bool's as bitlists/bitvectors are dealth with separately
    // Treat uint or bool as sequence of length 1 e.g. call pack([uint8])
    //  function pack(s: seq<Bytes>) : seq<chunk>
    //     // no upper bound on length of any individual serialised element???
    //     ensures forall i :: 0 <= i < |pack(s)| ==> is32BytesChunk(pack(s)[i])
    //     ensures 1 <= |pack(s)| 
    //  {        
    //     if |s| == 0 then [EMPTY_CHUNK]
    //     // else toChunks(concatSerialisedElements(s))  
    //     else toChunks(flatten(s))  
    // }

    /** bitfieldBytes.
     *
     *  @param  b   A sequence of bits (seq<bool>)
     *  @returns    A sequence of 32-byte chunks, right padded with zero bytes if |b| % 32 != 0
     *
     *  @note       This function is only applicable to a bitlist or bitvector. 
     *
     *  @note       Return the bits of the bitlist or bitvector, packed in bytes, aligned to the start. 
     *              Length-delimiting bit for bitlists is excluded (Reference: simple-serialize.md)
     *
     *  @note       Although not explicitly stated in the spec, it is assumed that the bytes are also
     *              packed into 32-byte chunks and that right padding is applied to ensure full chunks.
     *              This assumption is supported by the subsequent use of the function within the 
     *              merkleisation function, which expects input in the form of chunks.
     *
     *  @note       Unlike the pack function, it is not implied by the spec that at least one chunk is 
     *              returned.
     */
    
    function bitfieldBytes(b: seq<bool>) : seq<chunk>
        // no upper bound on length of any individual serialised element???
        ensures forall i :: 0 <= i < |bitfieldBytes(b)| ==> is32BytesChunk(bitfieldBytes(b)[i])
        ensures 0 <= |bitfieldBytes(b)| 
        //ensures |pack(s)| == max(1, ceil(flattenLength(s),32))      
     {        
        if |b| == 0 then []
        else toChunks(fromBitsToBytes(b)) 
    }

    function method hash(b: seq<Byte>): hash32
        requires |b|>=32
        ensures |hash(b)| == 32
    {
        b[..32] // TODO: update
        //EMPTY_CHUNK
    }

    predicate isPowerOf2(n: nat)
    {
        //(n == get_next_power_of_two(n))
        exists k:nat:: power2(k)==n 
        //x > 0 && ( x == 1 || ((x % 2 == 0) && isPowerOf2(x/2)) )
    }

    lemma Prop1(n: nat)
        ensures get_next_power_of_two(get_next_power_of_two(n)) == get_next_power_of_two(n)
    {
        //Thanks Dafny
    }

    lemma propPadPow2Chunks(chunks: seq<chunk>)
        requires 1 <= |chunks| 
        ensures get_next_power_of_two(|padPow2Chunks(chunks)|) == get_next_power_of_two(|chunks|)
    {
        calc == {
            get_next_power_of_two(|padPow2Chunks(chunks)|);
            ==
            get_next_power_of_two(get_next_power_of_two(|chunks|));
            ==
            {Prop1(|chunks|);} get_next_power_of_two(|chunks|);

        }
    }

    lemma propPadPow2ChunksLength(chunks: seq<chunk>)
         requires |chunks| >= 1
         ensures |padPow2Chunks(chunks)| == get_next_power_of_two(|padPow2Chunks(chunks)|) 
     {  
        calc == {
                |padPow2Chunks(chunks)|;
                ==
                get_next_power_of_two(|chunks|);
                ==
                {Prop1(|chunks|);} get_next_power_of_two(get_next_power_of_two(|chunks|));
                ==
                get_next_power_of_two(|padPow2Chunks(chunks)|) ;
            }
     }

    function method padPow2Chunks(chunks: seq<chunk>): seq<chunk>
        requires 1 <= |chunks| 
        ensures 1 <= |padPow2Chunks(chunks)| 
        ensures |padPow2Chunks(chunks)| == get_next_power_of_two(|chunks|)
        //ensures isPowerOf2(|padPow2Chunks(chunks)|)
    {
        if |chunks| == get_next_power_of_two(|chunks|) then chunks
        else chunks + timeSeq(EMPTY_CHUNK, get_next_power_of_two(|chunks|)-|chunks|)
    }

    function method merkleisePow2Chunks(chunks: seq<chunk>): hash32
        requires 1 <= |chunks| 
        requires |chunks| == get_next_power_of_two(|chunks|)
        //requires isPowerOf2(|chunks|)
        ensures is32BytesChunk(merkleisePow2Chunks(chunks))
        decreases chunks
    {
        if |chunks| == 1 then chunks[0]
        else hash(merkleisePow2Chunks(chunks[..(|chunks|/2)]) + merkleisePow2Chunks(chunks[|chunks|/2..]))
    }

    function method merkleise(chunks: seq<chunk>): hash32
        requires |chunks| >= 0
        ensures is32BytesChunk(merkleise(chunks))
    {
        
        if |chunks| == 0 then EMPTY_CHUNK
        else 
            propPadPow2ChunksLength(chunks);
            merkleisePow2Chunks(padPow2Chunks(chunks))
     }
    
    /** getHashTreeRoot.
     *
     *  @param  s   A serialisable object.
     *  @returns    A 32-byte chunk representing the root node of the merkle tree.
     */
    function getHashTreeRoot(s : Serialisable) : hash32
        ensures is32BytesChunk(getHashTreeRoot(s))
    {
        match s 
            case Bool(_) => merkleise(pack(s))

            case Uint8(_) => merkleise(pack(s))

            case Bitlist(xl) => merkleise(bitfieldBytes(xl))  

            case Bytes32(_) => merkleise(pack(s))
    }
 }