/*
 * Copyright 2020 ConsenSys Software Inc.
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

include "../../utils/Eth2Types.dfy"
include "../../ssz/Constants.dfy"
include "../../utils/Helpers.dfy"
include "../../utils/SetHelpers.dfy"

/**
 *  Provide datatype for fork choice rule (and LMD-GHOST)
 */
module AttestationsTypes {

    import opened Helpers
    import opened Eth2Types
    import opened Constants
    import opened SetHelpers

    // Containers

    /** 
     *  A Checkpoint. 
     *  
     *  Checkpoints have a slot number that is a multiple of
     *  SLOTS_PER_EPOCH and so only the multiplier `epoch` is needed.
     *  As per the Gasper paper, checkpoints are **pairs** consisting of
     *  an epoch and a block (called Epoch Boundary Pairs in the Gasper Paper.)
     *  
     *  @note   The block that is associated with this epoch should probably have a slot
     *          number that is smaller or equal to  epoch * SLOTS_PER_EPOCH (but may
     *          be strictly smaller).
     *  
     *  @link{https://benjaminion.xyz/eth2-annotated-spec/phase0/beacon-chain/#checkpoint}
     *
     *  @param  epoch   An `Epoch` index i.e. slot number multiple of SLOTS_PER_EPOCH.
     *                  This seems to be what is called `attestation epoch` in the Gasper paper.
     *  @param  root    A (hash of a) block that corresponds to this checkpoint.
     *
     *  @note           The epochs slot is not necessarily the same as the (block) root slot.
     *                  It seems reasonable to assume that root.slot <= epoch * SLOTS_PER_EPOCH, 
     *                  although it does not seem to appear anywhere in the specs.
     */
    datatype CheckPoint = CheckPoint(
        epoch: Epoch,
        root: Root        
    )    

    /** Default value for CheckPoint. */
    const DEFAULT_CHECKPOINT := CheckPoint(0 as Epoch, DEFAULT_BYTES32)

    /** 
     *  A vote ie. an AttestationData.  
     *  
     *  @link{https://benjaminion.xyz/eth2-annotated-spec/phase0/beacon-chain/#attestationdata}
     *
     *  @param  slot                A slot number. The slot in which the validator makes
     *                              the attestation. Each active validator should be making 
     *                              exactly one attestation per epoch. Validators have an 
     *                              assigned slot for their attestation, and it is recorded here.
     *  @param  beacon_block_root   Block determined to be the head of the chain as per running 
     *                              LMD-GHOST at that slot. This determines the chain (ancestors)
     *                              to be used to update justifications and finalisations.
     *                              The slot of this root should be less than or equal to slot.
     *  @param  source              The source (why should it be justified?) checkpoint (FFG link).
     *  @param  target              The target (why should it be justified) checkpoint (FFG link).
     *
     *  @note                       The `source` and `target` are not independent from the 
     *                              `beacon_block_root`. As specified in the Gasper paper, they 
     *                              must be LJ(-) and LE(-) respectively. 
     *                              LJ(-) is the last (most recent) justified checkpoint in 
     *                              view(beacon_block_root), and LE(-) is the last epoch boundary
     *                              pair in view(beacon_block_root).
     *
     *  @note                       We must have target.epoch == epoch(slot).
     *
     *
     *  @note   As (source, target) forms a pair, they should probably be grouped together
     *          say as a Link rather than provided separately. 
     *          The pair stands for a `vote` for a link between source and target.
     */
    datatype AttestationData = AttestationData(
        slot: Slot,
        // index, CommitteeIndex, not used, should be the committee the validator belongs to.
        beacon_block_root: Root, 
        source: CheckPoint,
        target: CheckPoint        //    target.epoch == epoch(slot)
    )    

    /**
     *  Default value for AttestationData.
     */
    const DEFAULT_ATTESTATION_DATA := 
        AttestationData(0 as Slot,  DEFAULT_BYTES32, DEFAULT_CHECKPOINT, DEFAULT_CHECKPOINT)

    // datatype AggregationBits 
    type AggregationBits = x : seq<bool> | |x| == MAX_VALIDATORS_PER_COMMITTEE witness DEFAULT_AGGREGATION_BITS

    const DEFAULT_AGGREGATION_BITS := timeSeq(false, MAX_VALIDATORS_PER_COMMITTEE)

    /**
     *  A Pending attestation (including a delay slot).
     *  
     *  @param  data    The actual data i.e. vote of the attestation.
     *  @todo:  enable other fileds.
     */
    datatype PendingAttestation = PendingAttestation(
        aggregation_bits: AggregationBits,
        data: AttestationData
        // inclusion_delay: Slot
        // proposer_index: ValidatorIndex
    )

    /*
    If we omit the signature we can use AttestationData in place of Attestation.
    class Attestation(Container):
    aggregation_bits: Bitlist[MAX_VALIDATORS_PER_COMMITTEE]
    data: AttestationData
    signature: BLSSignature
    */


    /**
     *  Default value for PendingAttestation.
     */
    const DEFAULT_PENDING_ATTESTATION := PendingAttestation(DEFAULT_AGGREGATION_BITS, DEFAULT_ATTESTATION_DATA)

    type ListOfAttestations = x : seq<PendingAttestation> | |x| <= MAX_ATTESTATIONS * SLOTS_PER_EPOCH as int witness DEFAULT_LIST_ATTESTATIONS

    /**
     *  Default bitvector of size 4 initialised with false.
     */
    const DEFAULT_LIST_ATTESTATIONS : seq<PendingAttestation> := []
    // timeSeq(DEFAULT_PENDING_ATTESTATION, MAX_ATTESTATIONS * SLOTS_PER_EPOCH as int)

}
