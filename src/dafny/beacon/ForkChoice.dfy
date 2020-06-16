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

include "../utils/Eth2Types.dfy"
include "BeaconChain.dfy"
include "StateTransition.dfy"

/**
 * Fork choice rule for the Beacon Chain.
 */
module ForkChoice {
    
    import opened Eth2Types
    import opened BeaconChain
    import opened StateTransition

    /**
     *  The default block header.
     */
    const EMPTY_BLOCK_HEADER := BeaconBlockHeader(0 as Slot, EMPTY_BYTES32, EMPTY_BYTES32)
    
    /**
     *  Genesis (initial) beacon state.
     *  
     *  @link{https://github.com/ethereum/eth2.0-specs/blob/dev/specs/phase0/beacon-chain.md#genesis-state}
     */
    const GENESIS_STATE := BeaconState(0, EMPTY_BLOCK_HEADER)

    /**
     *  Genesis block (header).
     *
     *  @link{https://github.com/ethereum/eth2.0-specs/blob/dev/specs/phase0/beacon-chain.md#genesis-block}
     *  @note   In this simplified version blocks are same as headers.
     */
    const GENESIS_BLOCK_HEADER := BeaconBlockHeader(
        0 as Slot,  
        EMPTY_BYTES32 , 
        hash_tree_root(GENESIS_STATE)
    )

    /**
     *  The store recording the blocks and the states.
     *  
     *  @param  blocks          maps hash_tree_root(b) to b
     *  @param  block_states    maps a Root (hash_tree_root of a block) to a state.
     *
     *  @note                   From the spec 
     *  @link{https://github.com/ethereum/eth2.0-specs/blob/dev/specs/phase0/fork-choice.md#on_block}           
     *  @todo                   It seems that blocks and block_states should have the same
     *                          keys at any time. We may prove it.
     */
    datatype Store = Store (
        blocks : map<Root, BeaconBlockHeader>,
        block_states : map<Root, BeaconState>
    )

    /**
     *  This function is specialised for the genesis state.
     *
     *  @param  anchor_state    A state to be regarded as a trusted state, to not 
     *                          roll back beyond. This should be the genesis state for a full client.
     *  
     *  @note                   The original code in python starts with:
     *                          var anchor_block_header := anchor_state.latest_block_header;
     *                          if (anchor_block_header.state_root == Bytes32()) {
     *                              anchor_block_header.state_root := hash_tree_root(anchor_state)
     *                          };
     *                          It is here implemented by forcing the condition to be true.
     *
     *  @note                   [from specs] The block for anchor_root is incorrectly initialized 
     *                          to the block 
     *                          header, rather than the full block. This does not affect 
     *                          functionality but will be cleaned up in subsequent releases.
     *
     *  @link{https://github.com/ethereum/eth2.0-specs/blob/dev/specs/phase0/fork-choice.md#get_forkchoice_store}
     */
    function method get_forkchoice_store(anchor_state: BeaconState) : Store 
        requires anchor_state.latest_block_header.state_root == EMPTY_BYTES32
    {
        var anchor_block_header := anchor_state.latest_block_header.(
            state_root := hash_tree_root(anchor_state)
        );
        var anchor_root := hash_tree_root(anchor_block_header);
        Store(
            map[anchor_root := anchor_block_header],    // blocks
            map[anchor_root := anchor_state]            //  block_states
        )
    }

    /**
     *  The genesis store.
     *
     *  @link{https://github.com/ethereum/eth2.0-specs/blob/dev/specs/phase0/fork-choice.md#get_forkchoice_store}
     */
    const GENESIS_STORE := get_forkchoice_store(GENESIS_STATE)

    /**
     *  Property of the genesis store.
     */
    lemma genesisStoreHasGenesisBlockAndState() 
        ensures GENESIS_STORE == Store(
            map[hash_tree_root(GENESIS_BLOCK_HEADER) := GENESIS_BLOCK_HEADER],
            map[hash_tree_root(GENESIS_BLOCK_HEADER) := GENESIS_STATE]
        )
    {   //  Thanks Dafny
    }

    /**
     *  A Beacon Chain environement (storage) i.e. with Store etc.
     */
    class Env {

        /**
         *  The record of blocks that have been added to the chain.
         *
         *  The store.Keys contain the hash tree root of the corresponding store.Values.
         */
        var store : Store

        /**
         *  Track the set of blocks that have been added to the store.
         *  A block is added to accepted block whenever the pre-conditions
         *  of `on_block`  are satisfied. This include R3 which specifies that 
         *  the block is `valid` i.e. `state_transition` can be computed (guarantee of
         *  no failed asserts.)
         */
        ghost var acceptedBlocks : set<BeaconBlockHeader>

        /**
         *  Start with the genesis store and one accepted block, GENESIS_BLOCK_HEADER
         */
        constructor ()  

            /** Trying to verify  storeInvariant2 generates boogie name error. */
            // ensures storeInvariant2()
            /** Verify storeInvariant2() manually. */
            // ensures acceptedBlocks == {GENESIS_BLOCK_HEADER}
            ensures hash_tree_root(GENESIS_BLOCK_HEADER) in store.block_states.Keys
            // ensures hash_tree_root(GENESIS_BLOCK_HEADER) in store.blocks.Keys
            ensures store.block_states[hash_tree_root(GENESIS_BLOCK_HEADER)].latest_block_header == GENESIS_BLOCK_HEADER.(state_root := EMPTY_BYTES32) 

            //  for some reason removing the previous ensures creates a name resolution error in
            //  Dafny.
            ensures storeIsValid(store)
        {  
            store := GENESIS_STORE;
            acceptedBlocks := { GENESIS_BLOCK_HEADER }; 
        }

        /** 
         *  The set of keys in the store.blocks is the same as store.block_states.Keys. 
         */
        predicate storeInvariant0(store: Store) 
            reads this
        {
            store.blocks.Keys == store.block_states.Keys 
        }

        /**
         *  The only block with slot 0 is the GENESIS_BLOCK.
         */
        predicate storeInvariant0a(store: Store) 
            reads this
        {
            forall r :: r in store.blocks.Keys ==>
                store.blocks[r].slot == 0 ==> store.blocks[r] == GENESIS_BLOCK_HEADER
        }

        /**
         *  Every accepted block is in the store its key is is the hash_tree_root.
         */
        predicate storeInvariant1(store: Store) 
            reads this
        {
            forall b :: b in acceptedBlocks ==> 
                hash_tree_root(b) in store.blocks.Keys 
                && store.blocks[hash_tree_root(b)] == b
        }

        /** 
         *  Every accepted block `b` has an associated state in block_states and
         *  the corresponding state has a latest_block_header that is the block `b`
         *  with its state_root field nullified.
         */
        predicate storeInvariant2(store: Store) 
            reads this 
        {
            forall b :: b in acceptedBlocks ==> 
                hash_tree_root(b) in store.block_states.Keys 
                && store.block_states[hash_tree_root(b)].latest_block_header == 
                        b.(state_root := EMPTY_BYTES32) 
                // && store.block_states[hash_tree_root(b)].slot <= b.slot
        }

        /**
         *  In this invariant it would be nice to have:
         *   hash_tree_root(b) in keys ==> b in acceptedBlocks (or Values)
         *  This would enable us to conclude that 
         *              hash_tree_root(b) !in store.blocks.Keys from  b !in acceptedBlocks
         *  and then we can omit
         *              requires hash_tree_root(b) !in store.blocks.Keys
         *  in on_block.
         */
        predicate storeInvariant3(store: Store) 
            reads this
        {
            acceptedBlocks == store.blocks.Values
        }

        /**
         *  For every block, the slot of its parent root is stricly less than its slot. 
         */
        predicate storeInvariant4(store: Store) 
            reads this
        {
            forall b :: b in acceptedBlocks && b != GENESIS_BLOCK_HEADER ==>
                b.parent_root in store.blocks.Keys
                && store.blocks[b.parent_root].slot < b.slot 
        }

        /**
         *  The slots for corresponding block and state in the store are equal.
         */
        predicate storeInvariant5(store: Store) 
            reads this
        {
            forall b :: b in acceptedBlocks && b != GENESIS_BLOCK_HEADER ==>
                b.parent_root in store.blocks.Keys
                && b.parent_root in store.block_states.Keys
                && store.blocks[b.parent_root].slot == store.block_states[b.parent_root].slot
        }

        /**
         *  The slots in store.blocks ans store.block_states are in sync for each key.
         */
        predicate storeInvariant6(store: Store) 
            reads this
        {
            forall b :: b in store.blocks.Keys ==>
                && b  in store.block_states.Keys
                && store.blocks[b].slot == store.block_states[b].slot
        }

        /**
         *  The chain b.slot -> b.parent_root.slot -> b.parent_root^2.slot -> ... is 
         *  strictly decreasding.
         */
        predicate storeInvariant7(store: Store) 
            reads this
        {
            forall b :: b in acceptedBlocks && b != GENESIS_BLOCK_HEADER ==>
                hash_tree_root(b) in store.blocks.Keys
                && b.parent_root in store.blocks.Keys
                && store.blocks[b.parent_root].slot < store.blocks[hash_tree_root(b)].slot
        }

        /**
         *  Collect the ancestors of a given key in the store.
         *
         *  @param  r       A root that is a (block) store key.
         *  @param  store   A store.
         */
        function ancestors(r: Root, store: Store) : seq<BeaconBlockHeader>
            requires r in store.blocks.Keys
            requires storeIsValid(store)

            ensures 1 <= |ancestors(r, store)| <= 1 + (store.blocks[r].slot  as int)
            ensures GENESIS_BLOCK_HEADER in ancestors(r, store)
            ensures forall i:: 1 <= i < |ancestors(r, store)| ==> 
                ancestors(r, store)[i].slot < ancestors(r, store)[i - 1].slot
            ensures ancestors(r, store)[ |ancestors(r, store)| - 1] == GENESIS_BLOCK_HEADER

            reads this

            decreases store.blocks[r].slot
        {
            if ( store.blocks[r].slot == 0 ) then
                //  By invariant 0a
                [ GENESIS_BLOCK_HEADER ]
            else 
                [ store.blocks[r] ] + ancestors(store.blocks[r].parent_root, store)
        }
       
        /**
         *  The proof that a store is chain follows directly from the properties
         *  of ancestors.
         *  
         *  @param  r       A root.
         *  @param  store   A store.
         *  @returns        Proof that a valid store is always a chain.
         */
        lemma aValidStoreIsAChain(r: Root, store: Store)    
            requires r in store.blocks.Keys
            requires storeIsValid(store)

            //  Length (number) of ancestors is less than the slot of Root.
            ensures 1 <= |ancestors(r, store)| <= 1 + (store.blocks[r].slot  as int)
            //  The GENESIS_BLOCK_HEADER is always in the ancestors.
            ensures GENESIS_BLOCK_HEADER in ancestors(r, store)
            //  At each level in the sequence, the slot number decreases.
            ensures forall i:: 1 <= i < |ancestors(r, store)| ==> 
                ancestors(r, store)[i].slot < ancestors(r, store)[i - 1].slot
            //  The last block in the chain is the GENESIS_BLOCK_HEADER
            ensures ancestors(r, store)[ |ancestors(r, store)| - 1] == GENESIS_BLOCK_HEADER
        {
            //  Thanks Dafny and follows directly from proof of ancestors.
        }

        /**
         *  Store is valid if all the invariants are satisfied,
         */
        predicate storeIsValid(store: Store) 
            reads this
        {
            true 
            && storeInvariant0(store)
            && storeInvariant0a(store)
            && storeInvariant1(store)
            && storeInvariant2(store)
            && storeInvariant3(store)
            && storeInvariant4(store)
            && storeInvariant5(store)
            && storeInvariant6(store)
            && storeInvariant7(store)
        }

        /**
         *  @param  pre_state   The last beacon state that the block is supposed to attach to.
         *                      This is not a real parameter as it is constrained to be
         *                      the state that corresponds to the bloc parent_root but here
         *                      for convenience and readability.
         *  @param  b           A block to be added to the chain.
         */
        method on_block(b: BeaconBlockHeader, pre_state : BeaconState) 

            requires storeIsValid(store)

            //  Do not process duplicates and check that the block is not already in.
            requires hash_tree_root(b) !in store.blocks.Keys
            requires b.parent_root in store.block_states    //  equivalent to being in blocks
            //  R1: set pre_state according to what b.parent_root is in the store.
            requires pre_state == store.block_states[b.parent_root]
            //  R2 : requires that `b` can be added to pre_state i.e. state_transition 
            //  pre-conditions are satisfied..
            requires isValid(pre_state, b)

            //  Record block.
            ensures acceptedBlocks == old(acceptedBlocks) + { b };
            //  Progress: the store size increases.
            ensures |acceptedBlocks| == |old(acceptedBlocks)| + 1
            //  The store size increases
            ensures |store.blocks| == |old(store.blocks)| + 1
            //  Preserves store validity.
            ensures storeIsValid(store)

            modifies this
        {
            // assert(hash_tree_root(b) !in store.blocks.Keys);
            // pre_state = store.block_states[block.parent_root].copy()
            // Blocks cannot be in the future. If they are, their consideration must be delayed until the are in the past.
            // assert get_current_slot(store) >= block.slot

            // Add new block to the store
            store := store.(blocks := store.blocks[hash_tree_root(b) := b] );
            acceptedBlocks := acceptedBlocks + { b };

            assert(b.parent_root in store.blocks.Keys);
            assert(b.parent_root in store.block_states.Keys);
            assert(store.block_states[b.parent_root].slot < b.slot);

            // Check that block is later than the finalized epoch slot (optimization to reduce calls to get_ancestor)
            // finalized_slot = compute_start_slot_at_epoch(store.finalized_checkpoint.epoch)
            // assert block.slot > finalized_slot
            // Check block is a descendant of the finalized block at the checkpoint finalized slot
            // assert get_ancestor(store, hash_tree_root(block), finalized_slot) == store.finalized_checkpoint.root

            // Check the block is valid and compute the post-state
            var new_state := stateTransition(pre_state, b);
           
            // Add new state for this block to the store
            store := store.(block_states := store.block_states[hash_tree_root(b) := new_state] );
        }
        
    }
}