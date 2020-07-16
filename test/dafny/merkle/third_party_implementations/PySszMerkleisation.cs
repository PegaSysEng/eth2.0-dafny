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
 
using System;
using System.Text;
using System.Numerics;
using System.Diagnostics;
using System.IO;
using System.Collections.Generic;
using System.Linq;

namespace thirdpartymerkleisation
{
    public partial class __default {
        
        /** Invoke PySSZ through an helper Python script to calculate the Merkle
         *  hash root of a Bitlist
         *
         *  @param bitlist The bitlist as a raw sequence of bool (without the
         *                 bit used as a sentinel for the length)
         *  @param bitlistInBytes   The raw bitlist (i.e. without the bit used 
         *                          as a sentinel for the length)encoded as a 
         *                          sequence of bytes. 
         *  @param limit The bitlist limit
         *  @returns The hashtree root of the supplied bitlist
         * 
         *  @note The reason for having both bitlist and bitlistInBytes parameters
         *  is that the former is used by the PySSZ bridge and the latter is used
         *  by the PrysmaticLab bridge.
         */
        public static Dafny.Sequence<byte>  BitlistRoot(Dafny.Sequence<bool> bitlist, Dafny.Sequence<byte> bitlistInBytes, BigInteger limit)
        {
                // Convert bitlist into a byte array
                byte[] bl = new byte[bitlist.Elements.Length];
                for(int i = 0; i<bitlist.Elements.Length;i++)
                {
                    if(bitlist.Elements[i])
                    {
                        bl[i] = 1;
                    }
                    else
                    {
                        bl[i] = 0;
                    }
                }

                // Set command and command line
                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = "python3";
                start.Arguments="PySszBitlistMerkleisation.py " + limit;

                // Set redirections for stdout and stdin
                start.UseShellExecute = false;
                start.RedirectStandardOutput = true;
                start.RedirectStandardInput = true;

                // Start the process
                Process cmdProcess = new Process();
                cmdProcess.StartInfo = start;
                cmdProcess.Start();    

                // Write to the process stdin in binary format and then closes
                // the stream
                var bw = new BinaryWriter(cmdProcess.StandardInput.BaseStream);
                bw.Write(bl); 
                cmdProcess.StandardInput.Close();  

                cmdProcess.WaitForExit();                           

                // Read from the process stdout in binary format and store the
                // read data in a byte array
                var br = new BinaryReader(cmdProcess.StandardOutput.BaseStream);
                byte[] retBytes = br.ReadBytes(32);

                // Convert the C# byte array containing the data read from the
                // process stdout to a Dafny sequence of byte
                return Dafny.Sequence<byte>.FromElements(retBytes);
        }

        /** Invoke PySSZ through an helper Python script to calculate the Merkle
         *  hash root of a bitvector
         */
        public static Dafny.Sequence<byte>  BitvectorRoot(Dafny.Sequence<bool> bitvector, Dafny.Sequence<byte> bitvectorInBytes)
        {               
                // Convert bitvector into a byte array
                byte[] bv = new byte[bitvector.Elements.Length];
                for(int i = 0; i<bitvector.Elements.Length;i++)
                {
                    if(bitvector.Elements[i])
                    {
                        bv[i] = 1;
                    }
                    else
                    {
                        bv[i] = 0;
                    }
                }
                
                ProcessStartInfo start = new ProcessStartInfo();

                // Set command and command line
                start.FileName = "python3";
                start.Arguments="PySszBitvectorMerkleisation.py";

                // Set redirections for stdin and stdout
                start.UseShellExecute = false;
                start.RedirectStandardOutput = true;
                start.RedirectStandardInput = true;

                // Start the process 
                Process cmdProcess = new Process();
                cmdProcess.StartInfo = start;
                cmdProcess.Start();

                // Write to the process stdin in binary format and then closes
                // the stream
                var bw = new BinaryWriter(cmdProcess.StandardInput.BaseStream);
                bw.Write(bv); 
                cmdProcess.StandardInput.Close();   

                // Read from the process stdout in binary format and store the
                // read data in a byte array
                var br = new BinaryReader(cmdProcess.StandardOutput.BaseStream);
                byte[] retBytes = br.ReadBytes(32);

                // Convert the C# byte array containing the data read from the
                // process stdout to a Dafny sequence of byte
                return Dafny.Sequence<byte>.FromElements(retBytes);
        }        
        
        /** Invoke PySSZ through an helper Python script to calculate the Merkle
         *  hash root of a Vector of Bytes
         */
        public static Dafny.Sequence<byte>  BytesRoot(Dafny.Sequence<byte> bs)
        {               
                ProcessStartInfo start = new ProcessStartInfo();

                // Set command and command line
                start.FileName = "python3";
                start.Arguments="PySszBytesMerkleisation.py";

                // Set redirections for stdin and stdout
                start.UseShellExecute = false;
                start.RedirectStandardOutput = true;
                start.RedirectStandardInput = true;

                // Start the process 
                Process cmdProcess = new Process();
                cmdProcess.StartInfo = start;
                cmdProcess.Start();

                // Write to the process stdin in binary format and then closes
                // the stream
                var bw = new BinaryWriter(cmdProcess.StandardInput.BaseStream);
                bw.Write(bs.Elements); 
                cmdProcess.StandardInput.Close();   

                // Read from the process stdout in binary format and store the
                // read data in a byte array
                var br = new BinaryReader(cmdProcess.StandardOutput.BaseStream);
                byte[] retBytes = br.ReadBytes(32);

                // Convert the C# byte array containing the data read from the
                // process stdout to a Dafny sequence of byte
                return Dafny.Sequence<byte>.FromElements(retBytes);
        }

        public static Dafny.Sequence<byte> ListUint64Root(Dafny.Sequence<BigInteger> listOfUints, BigInteger limit)
        {
                // Build the list of arguments for the Python script
                List<String> arguments = new List<String>();
                arguments.Add(limit.ToString());
                foreach(BigInteger n in listOfUints.Elements)
                {
                    arguments.Add(n.ToString());
                }

                // Set command and command line
                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = "python3";
                start.Arguments="PySszListOfUint64Merkleisation.py " + String.Join(" ",arguments.ToArray());

                // Set redirections for stdout
                start.UseShellExecute = false;
                start.RedirectStandardOutput = true;

                // Start the process
                Process cmdProcess = new Process();
                cmdProcess.StartInfo = start;
                cmdProcess.Start();                              

                // Read from the process stdout in binary format and store the
                // read data in a byte array
                var br = new BinaryReader(cmdProcess.StandardOutput.BaseStream);
                byte[] retBytes = br.ReadBytes(32);

                // Convert the C# byte array containing the data read from the
                // process stdout to a Dafny sequence of byte
                return Dafny.Sequence<byte>.FromElements(retBytes);
        } 
        public static Dafny.Sequence<byte> ListBytes32Root(Dafny.Sequence<Dafny.Sequence<byte>> listOfBytes32, BigInteger limit)
        {
                // Build the list of arguments for the Python script
                List<String> arguments = new List<String>();
                arguments.Add(limit.ToString());
                foreach(Dafny.Sequence<byte> s in listOfBytes32.Elements)
                {
                    foreach(BigInteger n in s.Elements)
                    {
                        arguments.Add(n.ToString());
                    }
                }

                // Set command and command line
                ProcessStartInfo start = new ProcessStartInfo();
                start.FileName = "python3";
                start.Arguments="PySszListOfBytes32Merkleisation.py " + String.Join(" ",arguments.ToArray());

                // Set redirections for stdout and stdin
                start.UseShellExecute = false;
                start.RedirectStandardOutput = true;

                // Start the process
                Process cmdProcess = new Process();
                cmdProcess.StartInfo = start;
                cmdProcess.Start();    

                // Read from the process stdout in binary format and store the
                // read data in a byte array
                var br = new BinaryReader(cmdProcess.StandardOutput.BaseStream);
                byte[] retBytes = br.ReadBytes(32);

                // Convert the C# byte array containing the data read from the
                // process stdout to a Dafny sequence of byte
                return Dafny.Sequence<byte>.FromElements(retBytes);
        }

        public static Dafny.Sequence<byte> BeaconStateRoot(_13_Eth2Types_Compile.RawSerialisable rawBeaconState)
        {
            // Convert RawSerialisable values to C# types
            _13_Eth2Types_Compile.RawSerialisable_BeaconState beaconState = (_13_Eth2Types_Compile.RawSerialisable_BeaconState)rawBeaconState;
            BigInteger firstSlot = ((_13_Eth2Types_Compile.RawSerialisable_Uint64)beaconState.slot).n;
            _13_Eth2Types_Compile.RawSerialisable_BeaconBlockHeader beaconBlockHeader = (_13_Eth2Types_Compile.RawSerialisable_BeaconBlockHeader)beaconState.latest__block__header;
            BigInteger secondSlot = ((_13_Eth2Types_Compile.RawSerialisable_Uint64)beaconBlockHeader.slot).n;
            IEnumerable<byte>  parent_root = ((_13_Eth2Types_Compile.RawSerialisable_Bytes)beaconBlockHeader.parent__root).bs.Elements;
            IEnumerable<byte>  state_root = ((_13_Eth2Types_Compile.RawSerialisable_Bytes)beaconBlockHeader.state__root).bs.Elements;
            IEnumerable<IEnumerable<byte> > block_roots = 
                from bs in ((Dafny.Sequence<_13_Eth2Types_Compile.RawSerialisable>)((_13_Eth2Types_Compile.RawSerialisable_Vector)beaconState.block__roots).v).Elements
                select ((_13_Eth2Types_Compile.RawSerialisable_Bytes)bs).bs.Elements;

            IEnumerable<IEnumerable<byte> > state_roots = 
                from bs in ((Dafny.Sequence<_13_Eth2Types_Compile.RawSerialisable>)((_13_Eth2Types_Compile.RawSerialisable_Vector)beaconState.state__roots).v).Elements
                select ((_13_Eth2Types_Compile.RawSerialisable_Bytes)bs).bs.Elements;                

            // Concatenate the string representations of the values of all the fields
            // into a space separated string
            List<String> arguments = new List<String>();
            arguments.Add(firstSlot.ToString());
            arguments.Add(secondSlot.ToString());
            parent_root.ToList().ForEach(b => arguments.Add(b.ToString()));
            state_root.ToList().ForEach(b => arguments.Add(b.ToString()));
            block_roots.ToList().ForEach(
                s => s.ToList().ForEach(
                    b => arguments.Add(b.ToString())
                )
            );
            state_roots.ToList().ForEach(
                s => s.ToList().ForEach(
                    b => arguments.Add(b.ToString())
                )
            );
            String argumentsWithSpaces = String.Join(" ",arguments.ToArray());

            // Set command and command line
            ProcessStartInfo start = new ProcessStartInfo();
            start.FileName = "python3";
            start.Arguments="PySszBeaconStateMerkleisation.py ";

            // Set redirections for stdout and stdin
            start.UseShellExecute = false;
            start.RedirectStandardInput = true;
            start.RedirectStandardOutput = true;

            // Start the process
            Process cmdProcess = new Process();
            cmdProcess.StartInfo = start;
            cmdProcess.Start();   

            // Write to the process stdin in binary format and then closes
            // the stream
            var bw = new BinaryWriter(cmdProcess.StandardInput.BaseStream);
            bw.Write(Encoding.UTF8.GetBytes(argumentsWithSpaces)); 
            cmdProcess.StandardInput.Close();  

            // Wait for the process to complete
            cmdProcess.WaitForExit();          

            var br = new BinaryReader(cmdProcess.StandardOutput.BaseStream);
            byte[] retBytes = br.ReadBytes(32);

            // Convert the C# byte array containing the data read from the
            // process stdout to a Dafny sequence of byte
            return Dafny.Sequence<byte>.FromElements(retBytes);  
        }
    }
}