--  GHDL Run Time (GRT) - VPI interface.
--  Copyright (C) 2002 - 2014 Tristan Gingold & Felix Bertram
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <gnu.org/licenses>.

-- Description: VPI interface for GRT runtime
--              the main purpose of this code is to interface with the
--              Icarus Verilog Interactive (IVI) simulator GUI

-------------------------------------------------------------------------------
-- TODO:
-------------------------------------------------------------------------------
-- DONE:
-- * The GHDL VPI implementation doesn't support time
--   callbacks (cbReadOnlySynch). This is needed to support
--   IVI run. Currently, the GHDL simulation runs until
--   complete once a single 'run' is performed...
-- * You are loading '_'-prefixed symbols when you
--   load the vpi plugin. On Linux, there is no leading
--   '_'. I just added code to try both '_'-prefixed and
--   non-'_'-prefixed symbols. I have placed the changed
--   file in the same download dir as the snapshot
-- * I did find out why restart doesn't work for GHDL.
--   You are passing back the leaf name of signals when the
--   FullName is requested.
-------------------------------------------------------------------------------

with Ada.Unchecked_Deallocation;

with Grt.Vhdl_Types; use Grt.Vhdl_Types;
with Grt.Stdio; use Grt.Stdio;
with Grt.C; use Grt.C;
with Grt.Signals; use Grt.Signals;
with Grt.Astdio; use Grt.Astdio;
with Grt.Astdio.Vhdl; use Grt.Astdio.Vhdl;
with Grt.Strings; use Grt.Strings;
with Grt.Hooks; use Grt.Hooks;
with Grt.Options; use Grt.Options;
with Grt.Vcd; use Grt.Vcd;
with Grt.Errors; use Grt.Errors;
with Grt.Rtis; use Grt.Rtis;
with Grt.Rtis_Types;
with Grt.Rtis_Addr;
with Grt.Std_Logic_1164; use Grt.Std_Logic_1164;
with Grt.Callbacks; use Grt.Callbacks;
with Grt.Vstrings; use Grt.Vstrings;
with Version;

package body Grt.Vpi is
   --  The VPI interface requires libdl (dlopen, dlsym) to be linked in.
   --  This is now set in Makefile, since this is target dependent.
   --  pragma Linker_Options ("-ldl");

   --errAnyString:     constant String := "grt-vcd.adb: any string" & NUL;
   --errNoString:      constant String := "grt-vcd.adb: no string" & NUL;

   Product : constant String := "GHDL" & NUL;
   GhdlVersion : constant String :=
      Version.Ghdl_Ver & " " & Version.Ghdl_Release & NUL;

   --  If true, emit traces
   Flag_Trace : Boolean := False;
   Trace_File : FILEs;
   Trace_Indent : Natural := 0;

-------------------------------------------------------------------------------
-- * * *   h e l p e r s   * * * * * * * * * * * * * * * * * * * * * * * * * *
-------------------------------------------------------------------------------

   ------------------------------------------------------------------------
   -- debugging helpers
   procedure dbgPut (Str : String)
   is
      S : size_t;
      pragma Unreferenced (S);
   begin
      S := fwrite (Str'Address, Str'Length, 1, stderr);
   end dbgPut;

   procedure dbgPut (C : Character)
   is
      R : int;
      pragma Unreferenced (R);
   begin
      R := fputc (Character'Pos (C), stderr);
   end dbgPut;

   procedure dbgNew_Line is
   begin
      dbgPut (Nl);
   end dbgNew_Line;

   procedure dbgPut_Line (Str : String)
   is
   begin
      dbgPut (Str);
      dbgNew_Line;
   end dbgPut_Line;

--    procedure dbgPut_Line (Str : Ghdl_Str_Len_Type)
--    is
--    begin
--       Put_Str_Len(stderr, Str);
--       dbgNew_Line;
--    end dbgPut_Line;

   procedure Free_Handle is new Ada.Unchecked_Deallocation
      (Name => vpiHandle, Object => struct_vpiHandle);

   procedure Free_Time is new Ada.Unchecked_Deallocation
      (Name => p_vpi_time, Object => s_vpi_time);

   procedure Free_Value is new Ada.Unchecked_Deallocation
      (Name => p_vpi_value, Object => s_vpi_value);

   ------------------------------------------------------------------------
   -- NUL-terminate strings.
   -- note: there are several buffers
   -- see IEEE 1364-2001
--   tmpstring1: string(1..1024);
--    function NulTerminate1 (Str : Ghdl_Str_Len_Type) return Ghdl_C_String
--    is
--    begin
--       for i in 1..Str.Len loop
--          tmpstring1(i):= Str.Str(i);
--       end loop;
--       tmpstring1(Str.Len+1):= NUL;
--       return To_Ghdl_C_String (tmpstring1'Address);
--    end NulTerminate1;

   --  Clear error status.
   procedure Reset_Error;

   procedure Trace_Start (Msg : String) is
   begin
      for I in 1 .. Trace_Indent loop
         Put (Trace_File, ' ');
      end loop;
      Put (Trace_File, Msg);
   end Trace_Start;

   procedure Trace (Msg : String) is
   begin
      Put (Trace_File, Msg);
   end Trace;

   procedure Trace (V : Integer) is
   begin
      Put_I32 (Trace_File, Ghdl_I32 (V));
   end Trace;

   procedure Trace_Cb_Reason (V : Integer) is
   begin
      case V is
         when cbValueChange =>
            Trace ("cbValueChange");
         when cbReadWriteSynch =>
            Trace ("cbReadWriteSynch");
         when cbReadOnlySynch =>
            Trace ("cbReadOnlySynch");
         when cbNextSimTime =>
            Trace ("cbNextSimTime");
         when cbAfterDelay =>
            Trace ("cbAfterDelay");
         when cbEndOfCompile =>
            Trace ("cbEndOfCompile");
         when cbStartOfSimulation =>
            Trace ("cbStartOfSimulation");
         when cbEndOfSimulation =>
            Trace ("cbEndOfSimulation");
         when others =>
            Trace (V);
      end case;
   end Trace_Cb_Reason;

   procedure Trace_Property (V : Integer) is
   begin
      case V is
         when vpiUndefined =>
            Trace ("vpiUndefined");
         when vpiType =>
            Trace ("vpiType");
         when vpiName =>
            Trace ("vpiName");
         when vpiFullName =>
            Trace ("vpiFullName");
         when vpiSize =>
            Trace ("vpiSize");
         when vpiFile =>
            Trace ("vpiFile");
         when vpiLineNo =>
            Trace ("vpiLineNo");

         when vpiDefName =>
            Trace ("vpiDefName");
         when vpiTimePrecision =>
            Trace ("vpiTimePrecision");
         when vpiDefFile =>
            Trace ("vpiDefFile");

         --  Port and net properties

         when vpiScalar =>
            Trace ("vpiScalar");
         when vpiVector =>
            Trace ("vpiVector");

         when vpiModule =>
            Trace ("vpiModule");
         when vpiNet =>
            Trace ("vpiNet");
         when vpiNetArray =>
            Trace ("vpiNetArray");
         when vpiPort =>
            Trace ("vpiPort");
         when vpiDirection =>
            Trace ("vpiDirection");
         when vpiParameter =>
            Trace ("vpiParameter");
         when vpiScope =>
            Trace ("vpiScope");
         when vpiInternalScope =>
            Trace ("vpiInternalScope");
         when vpiLeftRange =>
            Trace ("vpiLeftRange");
         when vpiRightRange =>
            Trace ("vpiRightRange");
         when vpiRange =>
            Trace ("vpiRange");

         when vpiStop =>
            Trace ("vpiStop");
         when vpiFinish =>
            Trace ("vpiFinish");
         when vpiReset =>
            Trace ("vpiReset");

         when others =>
            Trace (V);
      end case;
   end Trace_Property;

   procedure Trace_Format (F : Integer) is
   begin
      case F is
         when vpiBinStrVal =>
            Trace ("BinStr");
         when vpiOctStrVal =>
            Trace ("OctStr");
         when vpiDecStrVal =>
            Trace ("DecStr");
         when vpiHexStrVal =>
            Trace ("HexStr");
         when vpiScalarVal =>
            Trace ("Scalar");
         when vpiIntVal =>
            Trace ("Int");
         when vpiRealVal =>
            Trace ("Real");
         when vpiStringVal =>
            Trace ("String");
         when vpiVectorVal =>
            Trace ("Vector");
         when vpiStrengthVal =>
            Trace ("Strength");
         when vpiTimeVal =>
            Trace ("Time");
         when vpiObjTypeVal =>
            Trace ("ObjType");
         when vpiSuppressVal =>
            Trace ("Suppress");

         when others =>
            Trace (F);
      end case;
   end Trace_Format;

   procedure Trace_Time_Tag (V : Integer) is
   begin
      case V is
         when vpiScaledRealTime =>
            Trace ("vpiScaledRealTime");
         when vpiSimTime =>
            Trace ("vpiSimTime");
         when vpiSuppressTime =>
            Trace ("vpiSuppressTime");
         when others =>
            Trace (V);
      end case;
   end Trace_Time_Tag;

   procedure Trace_Put_Flags (V : Integer) is
   begin
      case V is
         when vpiNoDelay =>
            Trace ("vpiNoDelay");
         when vpiInertialDelay =>
            Trace ("vpiInertialDelay");
         when vpiTransportDelay =>
            Trace ("vpiTransportDelay");
         when vpiPureTransportDelay =>
            Trace ("vpiPureTransportDelay");
         when vpiForceFlag =>
            Trace ("vpiForceFlag");
         when vpiReleaseFlag =>
            Trace ("vpiReleaseFlag");
         when vpiCancelEvent =>
            Trace ("vpiCancelEvent");
         when others =>
            Trace (V);
      end case;
   end Trace_Put_Flags;

   procedure Trace (H : vpiHandle)
   is
      function To_Address is
         new Ada.Unchecked_Conversion (vpiHandle, System.Address);
   begin
      Put (Trace_File, To_Address (H));
   end Trace;

   procedure Trace (Str : Ghdl_C_String) is
   begin
      if Str = null then
         Put (Trace_File, "null");
      else
         Put (Trace_File, '"');
         Put (Trace_File, Str);
         Put (Trace_File, '"');
      end if;
   end Trace;

   procedure Trace_Time (V : Std_Time) is
   begin
      Put_Time (Trace_File, V);
   end Trace_Time;

   procedure Trace_Value (V : p_vpi_value) is
   begin
      case V.Format is
         when vpiBinStrVal
           | vpiOctStrVal
           | vpiDecStrVal
           | vpiHexStrVal
           | vpiStringVal =>
            Trace (V.Str);
         when vpiScalarVal =>
            Trace (V.Scalar);
         when vpiIntVal =>
            Trace (V.Integer_m);
            --when vpiRealVal=>     null; -- what is the equivalent to double?
            --when vpiTimeVal=>     mTime:     p_vpi_time;
            --when vpiVectorVal=>   mVector:   p_vpi_vecval;
            --when vpiStrengthVal=> mStrength: p_vpi_strengthval;
         when others =>
            null;
      end case;
   end Trace_Value;

   procedure Trace_Newline is
   begin
      New_Line (Trace_File);
   end Trace_Newline;

   function Vpi_Time_To_Time (V : s_vpi_time) return Std_Time is
      Res : Std_Time;
   begin
      case V.mType is
         when vpiScaledRealTime =>
            Res := Std_Time (Unsigned_64 (V.mReal / Time_Scale_Unit));
         when vpiSimTime =>
            Res := Std_Time (Unsigned_64 (V.mHigh) * 2 ** 32);
            Res := Res + Std_Time (V.mLow);
         when others =>
            raise Program_Error;
      end case;
      return Res;
   end Vpi_Time_To_Time;

-------------------------------------------------------------------------------
-- * * *   V P I   f u n c t i o n s   * * * * * * * * * * * * * * * * * * * *
-------------------------------------------------------------------------------

   --  Free a handle, checking for attached memory.
   procedure Free (H : in out vpiHandle) is
   begin
      if H = null then
         return;
      end if;
      if H.mType = vpiCallback then
         if H.Cb.Time /= null then
            Free_Time (H.Cb.Time);
         end if;
         if H.Cb.Value /= null then
            Free_Value (H.Cb.Value);
         end if;
      end if;
      Free_Handle (H);
   end Free;

   --  Free an handle, when it was not passed by reference.
   procedure Free_Copy (H : vpiHandle)
   is
      Copy : vpiHandle;
   begin
      Copy := H;
      Free (Copy);
   end Free_Copy;

   ------------------------------------------------------------------------
   -- vpiHandle  vpi_iterate(int type, vpiHandle ref)
   -- Obtain an iterator handle to objects with a one-to-many relationship.
   -- see IEEE 1364-2001, page 685
   function Vpi_Iterate_Internal
     (aType: integer; Ref: vpiHandle) return vpiHandle
   is
      Res : vpiHandle;
      Rel : VhpiOneToManyT;
      Error : AvhpiErrorT;
   begin
      case aType is
         when vpiPort
            | vpiNet =>
            Rel := VhpiDecls;
         when vpiModule =>
            if Ref = null then
               Res := new struct_vpiHandle (vpiModule);
               Get_Root_Inst (Res.Ref);
               return Res;
            else
               Rel := VhpiInternalRegions;
            end if;
         when vpiInternalScope =>
            Rel := VhpiInternalRegions;
         when others =>
            return null;
      end case;

      -- find the proper start object for our scan
      if Ref = null then
         Res := null;
      else
         Res := new struct_vpiHandle (aType);
         Vhpi_Iterator (Rel, Ref.Ref, Res.Ref, Error);

         if Error /= AvhpiErrorOk then
            Free (Res);
         end if;
      end if;

      return Res;
   end Vpi_Iterate_Internal;

   function vpi_iterate (aType: integer; Ref: vpiHandle) return vpiHandle
   is
      Res : vpiHandle;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_iterate (");
         Trace_Property (aType);
         Trace (", ");
         Trace (Ref);
         Trace (") = ");
      end if;

      Res := Vpi_Iterate_Internal (aType, Ref);

      if Flag_Trace then
         Trace (Res);
         Trace_Newline;
      end if;

      return Res;
   end vpi_iterate;

   ------------------------------------------------------------------------
   -- int vpi_get(int property, vpiHandle ref)
   -- Get the value of an integer or boolean property of an object.
   -- see IEEE 1364-2001, chapter 27.6, page 667
--    function ii_vpi_get_type (aRef: Ghdl_Instance_Name_Acc) return Integer
--    is
--    begin
--       case aRef.Kind is
--          when Ghdl_Name_Entity
--            | Ghdl_Name_Architecture
--            | Ghdl_Name_Block
--            | Ghdl_Name_Generate_Iterative
--            | Ghdl_Name_Generate_Conditional
--            | Ghdl_Name_Instance =>
--             return vpiModule;
--          when Ghdl_Name_Signal =>
--             return vpiNet;
--          when others =>
--             return vpiUndefined;
--       end case;
--    end ii_vpi_get_type;

   function Vpi_Get_Size (Ref : vpiHandle) return Integer
   is
      Info : Verilog_Wire_Info;
   begin
      Get_Verilog_Wire (Ref.Ref, Info);
      case Info.Vtype is
         when Vcd_Var_Vectors
            | Vcd_Array =>
            return Natural (Get_Wire_Length (Info));
         when Vcd_Bool
            | Vcd_Bit
            | Vcd_Stdlogic =>
            return 1;
         when Vcd_Integer32 =>
            return 32;
         when Vcd_Enum8 =>
            return 8;
         when Vcd_Float64 =>
            return 0;
         when Vcd_Bad
            | Vcd_Struct =>
            return 0;
      end case;
   end Vpi_Get_Size;

   function Vpi_Get_Vector (Ref : vpiHandle) return Boolean
   is
      Info : Verilog_Wire_Info;
   begin
      Get_Verilog_Wire (Ref.Ref, Info);
      case Info.Vtype is
         when Vcd_Bool
           | Vcd_Integer32
           | Vcd_Float64
           | Vcd_Bit
           | Vcd_Stdlogic
           | Vcd_Enum8 =>
            return False;
         when Vcd_Bitvector
           | Vcd_Stdlogic_Vector =>
            return True;
         when Vcd_Bad
           | Vcd_Struct
           | Vcd_Array =>
            return False;
      end case;
   end Vpi_Get_Vector;

   function vpi_get (Property: integer; Ref: vpiHandle) return Integer
   is
      Res : Integer;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_get (");
         Trace_Property (Property);
         Trace (", ");
         Trace (Ref);
         Trace (") = ");
      end if;

      case Property is
         when vpiType =>
            Res := Ref.mType;
         when vpiTimePrecision =>
            Res := -3 * Options.Time_Resolution_Scale;
         when vpiSize =>
            Res := Vpi_Get_Size (Ref);
         when vpiVector =>
            Res := Boolean'Pos (Vpi_Get_Vector (Ref));
         when vpiDirection =>
            case Vhpi_Get_Mode (Ref.Ref) is
               when VhpiInMode =>
                  Res := vpiInput;
               when VhpiOutMode =>
                  Res := vpiOutput;
               when VhpiInoutMode =>
                  Res := vpiInout;
               when others =>
                  Res := vpiNoDirection;
            end case;
         when others =>
            dbgPut_Line ("vpi_get: unknown property");
            Res := 0;
      end case;

      if Flag_Trace then
         case Property is
            when vpiType =>
               Trace_Property (Res);
            when others =>
               Trace (Res);
         end case;
         Trace_Newline;
      end if;

      return Res;
   end vpi_get;

   function Vhpi_Handle_To_Vpi_Net (Res : VhpiHandleT) return Integer
   is
      Info : Verilog_Wire_Info;
   begin
      Get_Verilog_Wire (Res, Info);
      case Info.Vtype is
         when Vcd_Enum8
           | Vcd_Bool
           | Vcd_Var_Vectors
           | Vcd_Integer32
           | Vcd_Bit
           | Vcd_Stdlogic =>
            return vpiNet;
         when Vcd_Array =>
            return vpiNetArray;
         when Vcd_Bad
           | Vcd_Struct
           | Vcd_Float64 =>
            return vpiUndefined;
      end case;
   end Vhpi_Handle_To_Vpi_Net;

   function Vhpi_Handle_To_Vpi_Prop (Res : VhpiHandleT; Irel : Integer)
                                    return Integer is
   begin
      case Vhpi_Get_Kind (Res) is
         when VhpiEntityDeclK
            | VhpiArchBodyK
            | VhpiBlockStmtK
            | VhpiIfGenerateK
            | VhpiForGenerateK
            | VhpiCompInstStmtK =>
            return vpiModule;
         when VhpiPortDeclK =>
            if Irel = vpiPort then
               declare
                  Info : Verilog_Wire_Info;
               begin
                  Get_Verilog_Wire (Res, Info);
                  if Info.Vtype /= Vcd_Bad then
                     return vpiPort;
                  end if;
               end;
            else
               return Vhpi_Handle_To_Vpi_Net (Res);
            end if;
         when VhpiSigDeclK =>
            return Vhpi_Handle_To_Vpi_Net (Res);
         when VhpiGenericDeclK =>
            declare
               Info : Verilog_Wire_Info;
            begin
               Get_Verilog_Wire (Res, Info);
               if Info.Vtype /= Vcd_Bad then
                  return vpiParameter;
               end if;
            end;
         when VhpiConstDeclK =>
            declare
               Info : Verilog_Wire_Info;
            begin
               Get_Verilog_Wire (Res, Info);
               if Info.Vtype /= Vcd_Bad then
                  return vpiConstant;
               end if;
            end;
         when others =>
            null;
      end case;
      return vpiUndefined;
   end Vhpi_Handle_To_Vpi_Prop;

   function Build_vpiHandle (Res : VhpiHandleT; Prop : Integer)
                            return vpiHandle is
   begin
      case Prop is
         when vpiModule =>
            return new struct_vpiHandle'(mType => vpiModule,
                                         Ref => Res);
         when vpiNet =>
            return new struct_vpiHandle'(mType => vpiNet,
                                         Ref => Res);
         when vpiNetArray =>
            return new struct_vpiHandle'(mType => vpiNetArray,
                                         Ref => Res);
         when vpiPort =>
            return new struct_vpiHandle'(mType => vpiPort,
                                         Ref => Res);
         when vpiParameter =>
            return new struct_vpiHandle'(mType => vpiParameter,
                                         Ref => Res);
         when vpiConstant =>
            return new struct_vpiHandle'(mType => vpiConstant,
                                         Ref => Res);
         when others =>
            return null;
      end case;
   end Build_vpiHandle;

   function Vhpi_Handle_To_Vpi (H : VhpiHandleT) return vpiHandle
   is
      Prop : Integer;
   begin
      Prop := Vhpi_Handle_To_Vpi_Prop (H, vpiUndefined);
      if Prop /= vpiUndefined then
         return Build_vpiHandle (H, Prop);
      else
         return null;
      end if;
   end Vhpi_Handle_To_Vpi;

   ------------------------------------------------------------------------
   -- vpiHandle  vpi_scan(vpiHandle iter)
   -- Scan the Verilog HDL hierarchy for objects with a one-to-many
   -- relationship.
   -- see IEEE Std 1800-2017, chapter 38.40, page 1109
   function Vpi_Scan_Internal (Iter: vpiHandle) return vpiHandle
   is
      Res : VhpiHandleT;
      Error : AvhpiErrorT;
      R : vpiHandle;
      Kind, Expected_Kind : Integer;
   begin
      --  End of scan reached.  Avoid a crash in case of misuse.
      if Iter = null then
         return null;
      end if;

      --  There is only one top-level module.
      if Iter.mType = vpiModule then
         case Vhpi_Get_Kind (Iter.Ref) is
            when VhpiRootInstK =>
               R := new struct_vpiHandle (Iter.mType);
               R.Ref := Iter.Ref;
               Iter.Ref := Null_Handle;
               return R;
            when VhpiUndefined =>
               --  End of iteration.
               return null;
            when others =>
               --  Fall through.
               null;
         end case;
      end if;

      case Iter.mType is
         when vpiInternalScope
           | vpiModule =>
            Expected_Kind := vpiModule;
         when vpiPort =>
            Expected_Kind := vpiPort;
         when vpiNet =>
            Expected_Kind := vpiNet;
         when others =>
            Expected_Kind := vpiUndefined;
      end case;

      loop
         Vhpi_Scan (Iter.Ref, Res, Error);
         exit when Error /= AvhpiErrorOk;

         Kind := Vhpi_Handle_To_Vpi_Prop (Res, Iter.mType);
         if Kind /= vpiUndefined
           and then (Kind = Expected_Kind
                       or (Kind = vpiPort and Expected_Kind = vpiNet))
         then
            return Build_vpiHandle (Res, Kind);
         end if;
      end loop;

      return null;
   end Vpi_Scan_Internal;

   function vpi_scan (Iter: vpiHandle) return vpiHandle
   is
      Res : vpiHandle;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_scan (");
         Trace (Iter);
         Trace (") = ");
      end if;

      Res := Vpi_Scan_Internal (Iter);

      if Flag_Trace then
         Trace (Res);
         Trace_Newline;
      end if;

      --  IEEE 1364-2005 27.5 vpi_free_object()
      --  The iterator object shall automatically be freed when vpi_scan()
      --  returns NULL because it has either completed an object traversal
      --  or encountered an error condition.
      --  Free the iterator.
      if Res = null then
         Free_Copy (Iter);
      end if;

      return Res;
   end vpi_scan;

   ------------------------------------------------------------------------
   -- char *vpi_get_str(int property, vpiHandle ref)
   -- see IEEE Std 1800-2017, page 1061
   Tmpstring2 : String (1 .. 1024);
   function Vpi_Get_Str_Internal (Property : Integer; Ref : vpiHandle)
                                 return Ghdl_C_String
   is
      Prop : VhpiStrPropertyT;
      Len : Natural;
      Res : Ghdl_C_String;

      procedure Copy_VpiType_CString is
         R : String renames Tmpstring2;
         procedure Add (C : Character) is
         begin
            Len := Len + 1;
            if Len <= R'Last then
               R (Len) := C;
            end if;
         end Add;

         procedure Add (Str : String) is
         begin
            for I in Str'Range loop
               Add (Str (I));
            end loop;
         end Add;

      begin
         Len := 0;
         case Vhpi_Handle_To_Vpi_Prop (Ref.Ref, vpiUndefined) is
            when vpiUndefined =>
               Add ("vpiUndefined");
            when vpiType =>
               Add ("vpiType");
            when vpiName =>
               Add ("vpiName");
            when vpiFullName =>
               Add ("vpiFullName");
            when vpiSize =>
               Add ("vpiSize");
            when vpiTimePrecision =>
               Add ("vpiTimePrecision");
            when vpiScalar =>
               Add ("vpiScalar");
            when vpiVector =>
               Add ("vpiVector");
            when vpiModule =>
               Add ("vpiModule");
            when vpiDefFile =>
               Add ("vpiDefFile");
            when vpiNet =>
               Add ("vpiNet");
            when vpiNetArray =>
               Add ("vpiNetArray");
            when vpiPort =>
               Add ("vpiPort");
            when vpiDirection =>
               Add ("vpiDirection");
            when vpiParameter =>
               Add ("vpiParameter");
            when vpiScope =>
               Add ("vpiScope");
            when vpiInternalScope =>
               Add ("vpiInternalScope");
            when vpiLeftRange =>
               Add ("vpiLeftRange");
            when vpiRightRange =>
               Add ("vpiRightRange");
            when vpiStop =>
               Add ("vpiStop");
            when vpiFinish =>
               Add ("vpiFinish");
            when vpiReset =>
               Add ("vpiReset");
            when others =>
               return;
         end case;
         R (Len + 1) := NUL;
      end Copy_VpiType_CString;

   begin
      if Ref = null then
         return null;
      end if;

      case Property is
         when vpiFullName =>
            Prop := VhpiFullNameP;
         when vpiName =>
            Prop := VhpiNameP;
         when vpiDefFile =>
            Prop := VhpiFileNameP;
         when vpiType =>
            Copy_VpiType_CString;
            if Len = 0 then
               return null;
            else
               return To_Ghdl_C_String (Tmpstring2'Address);
            end if;
         when others =>
            dbgPut_Line ("vpi_get_str: unhandled property");
            return null;
      end case;
      Vhpi_Get_Str (Prop, Ref.Ref, Tmpstring2, Len);
      Tmpstring2 (Len + 1) := NUL;
      if Property = vpiFullName then
         for I in Tmpstring2'First .. Len loop
            if Tmpstring2 (I) = ':' then
               Tmpstring2 (I) := '.';
            end if;
         end loop;
         --  Remove the initial '.'.
         Res := To_Ghdl_C_String (Tmpstring2 (2)'Address);
      else
         Res := To_Ghdl_C_String (Tmpstring2'Address);
      end if;

      return Res;
   end Vpi_Get_Str_Internal;

   function vpi_get_str (Property : Integer; Ref : vpiHandle)
                        return Ghdl_C_String
   is
      Res : Ghdl_C_String;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_get_str (");
         Trace_Property (Property);
         Trace (", ");
         Trace (Ref);
         Trace (") = ");
      end if;

      Res := Vpi_Get_Str_Internal (Property, Ref);

      if Flag_Trace then
         Trace (Res);
         Trace_Newline;
      end if;

      return Res;
   end vpi_get_str;
   ------------------------------------------------------------------------
   -- vpiHandle  vpi_handle(int type, vpiHandle ref)
   -- Obtain a handle to an object with a one-to-one relationship.
   -- see IEEE 1364-2001, chapter 27.16, page 682
   function Vpi_Handle_Internal
     (aType : Integer; Ref : vpiHandle) return vpiHandle
   is
      Res : vpiHandle;
   begin
      if Ref = null then
         return null;
      end if;

      case aType is
         when vpiScope =>
            case Ref.mType is
               when vpiModule =>
                  Res := new struct_vpiHandle (vpiScope);
                  Res.Ref := Ref.Ref;
                  return Res;
               when others =>
                  return null;
            end case;
         when vpiRightRange
            | vpiLeftRange =>
            case Ref.mType is
               when vpiPort
                  | vpiNet
                  | vpiNetArray =>
                  Res := new struct_vpiHandle (aType);
                  Res.Ref := Ref.Ref;
                  return Res;
               when others =>
                  return null;
            end case;
         when others =>
            return null;
      end case;
   end Vpi_Handle_Internal;

   function vpi_handle (aType : Integer; Ref : vpiHandle) return vpiHandle
   is
      Res : vpiHandle;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_handle (");
         Trace_Property (aType);
         Trace (", ");
         Trace (Ref);
         Trace (") = ");
      end if;

      Res := Vpi_Handle_Internal (aType, Ref);

      if Flag_Trace then
         Trace (Res);
         Trace_Newline;
      end if;

      return Res;
   end vpi_handle;

   ------------------------------------------------------------------------
   -- void  vpi_get_value(vpiHandle expr, p_vpi_value value);
   -- Retrieve the simulation value of an object.
   -- see IEEE 1364-2001, chapter 27.14, page 675
   Buf_Value : Vstring (64);

   procedure Append_Bin (V : Ghdl_U64; Ndigits : Natural) is
   begin
      for I in reverse 0 .. Ndigits - 1 loop
         if (Shift_Right (V, I) and 1) /= 0 then
            Append (Buf_Value, '1');
         else
            Append (Buf_Value, '0');
         end if;
      end loop;
   end Append_Bin;

   type Map_Type_E8 is array (Ghdl_E8 range 0..8) of character;
   Map_Std_E8: constant Map_Type_E8 := "UX01ZWLH-";

   type Map_Type_E8_Int is array (Ghdl_E8 range 0..8) of Ghdl_I32;
   Map_Std_E8_Int: constant Map_Type_E8_Int := (0, 0, 0, 1, 0, 0, 0, 1, 0);

   type Map_Type_B1 is array (Ghdl_B1) of character;
   Map_Std_B1: constant Map_Type_B1 := "01";

   function Get_Value_Obj (Obj : VhpiHandleT) return Verilog_Wire_Info
   is
      Info : Verilog_Wire_Info;
   begin
      case Vhpi_Get_Kind (Obj) is
         when VhpiPortDeclK
            | VhpiSigDeclK
            | VhpiGenericDeclK
            | VhpiConstDeclK
            | VhpiIndexedNameK =>
            Get_Verilog_Wire (Obj, Info);
            return Info;
         when others =>
            return (Vtype => Vcd_Bad,
                    Val => Vcd_Effective, Ptr => Null_Address);
      end case;
   end Get_Value_Obj;

   function E8_To_Char (Val : Ghdl_E8) return Character is
   begin
      if Val not in Map_Type_E8'range then
         return '?';
      else
         return Map_Std_E8 (Val);
      end if;
   end E8_To_Char;

   function Vpi_Get_Value_Bin (Obj : VhpiHandleT) return Ghdl_C_String
   is
      Info : Verilog_Wire_Info;
      Len : Ghdl_Index_Type;
   begin
      Info := Get_Value_Obj (Obj);

      Reset (Buf_Value); -- reset string buffer

      case Info.Vtype is
         when Vcd_Bad
            | Vcd_Float64
            | Vcd_Array
            | Vcd_Struct =>
            return null;
         when Vcd_Enum8 =>
            declare
               V : Ghdl_E8;
            begin
               V := Verilog_Wire_Val (Info).E8;
               Append_Bin (Ghdl_U64 (V), 8);
            end;
         when Vcd_Integer32 =>
            declare
               V : Ghdl_U32;
            begin
               V := Verilog_Wire_Val (Info).E32;
               Append_Bin (Ghdl_U64 (V), 32);
            end;
         when Vcd_Bit
            | Vcd_Bool =>
            Append (Buf_Value, Map_Std_B1 (Verilog_Wire_Val (Info).B1));
         when Vcd_Bitvector =>
            Len := Get_Wire_Length (Info);
            for J in 0 .. Len - 1 loop
               Append (Buf_Value, Map_Std_B1 (Verilog_Wire_Val (Info, J).B1));
            end loop;
         when Vcd_Stdlogic =>
            Append (Buf_Value, E8_To_Char (Verilog_Wire_Val (Info).E8));
         when Vcd_Stdlogic_Vector =>
            Len := Get_Wire_Length (Info);
            for J in 0 .. Len - 1 loop
               Append (Buf_Value, E8_To_Char (Verilog_Wire_Val (Info, J).E8));
            end loop;
      end case;
      Append (Buf_Value, NUL);
      return Get_C_String (Buf_Value);
   end Vpi_Get_Value_Bin;

   function Vpi_Get_Value_Int (Obj : VhpiHandleT) return VhpiIntT
   is
      function E8_To_Int (Val : Ghdl_E8) return VhpiIntT is
      begin
         if Val not in Map_Type_E8_Int'range then
            return 0;
         else
            return Map_Std_E8_Int (Val);
         end if;
      end E8_To_Int;

      Info : Verilog_Wire_Info;
      Len : Ghdl_Index_Type;
      Res : VhpiIntT;
   begin
      Info := Get_Value_Obj (Obj);

      Reset (Buf_Value); -- reset string buffer

      case Info.Vtype is
         when Vcd_Bad
            | Vcd_Float64
            | Vcd_Array
            | Vcd_Struct =>
            --  FIXME: is it possible to return an error ?
            dbgPut_Line ("vpi_get_value: vpiIntVal, unknown mType");
            return -1;
         when Vcd_Enum8 =>
            declare
               V : Ghdl_E8;
            begin
               V := Verilog_Wire_Val (Info).E8;
               return Ghdl_E8'Pos (V);
            end;
         when Vcd_Integer32 =>
            declare
               V : Ghdl_U32;
            begin
               V := Verilog_Wire_Val (Info).E32;
               return To_Ghdl_I32 (V);
            end;
         when Vcd_Bit
            | Vcd_Bool =>
            return Ghdl_B1'Pos (Verilog_Wire_Val (Info).B1);
         when Vcd_Bitvector =>
            Res := 0;
            Len := Get_Wire_Length (Info);
            --  FIXME: handle overflow ?
            for J in 0 .. Len - 1 loop
               Res := Res * 2 + Ghdl_B1'Pos (Verilog_Wire_Val (Info, J).B1);
            end loop;
            return Res;
         when Vcd_Stdlogic =>
            return E8_To_Int (Verilog_Wire_Val (Info).E8);
         when Vcd_Stdlogic_Vector =>
            Len := Get_Wire_Length (Info);
            Res := 0;
            for J in 0 .. Len - 1 loop
               Res := Res * 2 + E8_To_Int (Verilog_Wire_Val (Info, J).E8);
            end loop;
            return Res;
      end case;
   end Vpi_Get_Value_Int;

   function To_Unsigned_32 is new Ada.Unchecked_Conversion
     (Integer, Unsigned_32);

   procedure Vpi_Get_Value_Vecval (Obj : VhpiHandleT; Vec : p_vpi_vecval)
   is
      procedure E8_To_VV
         (V : Ghdl_E8; A : out Unsigned_32; B : out Unsigned_32) is
      begin
         B := 0;
         case E8_To_Char (V) is
            when '0'
               | 'L' =>
               A := 0;
            when '1'
               | 'H' =>
               A := 1;
            when 'Z' =>
               A := 0;
               B := 1;
            when others =>
               A := 1;
               B := 1;
            end case;
      end E8_To_VV;

      Info : Verilog_Wire_Info;
      Len, Chunks, Bits, Base : Ghdl_Index_Type;
      A, Aall, B, Ball : Unsigned_32;
      Pointer : p_vpi_vecval;
   begin
      Info := Get_Value_Obj (Obj);

      case Info.Vtype is
         when Vcd_Bitvector
            | Vcd_Stdlogic_Vector =>
            null; -- Continues below.
         when Vcd_Stdlogic =>
            E8_To_VV (Verilog_Wire_Val (Info).E8, Vec.aval, Vec.bval);
            return;
         when others =>
            Vec.aval :=  To_Unsigned_32 (Integer (Vpi_Get_Value_Int (Obj)));
            Vec.bval := 0;
            return;
      end case;

      Len := Get_Wire_Length (Info);
      Chunks := (Len + 31) / 32;
      Pointer := Vec;
      Base := 0;

      for I in 0 .. Chunks - 1 loop
         if I < Chunks - 1 then
            Bits := 32;
         else
            Bits := Len mod 32;
         end if;

         Aall := 0;

         if Info.Vtype = Vcd_Bitvector then
            for J in reverse 0 .. Bits - 1 loop
               A := Ghdl_B1'Pos (Verilog_Wire_Val (Info, Base + J).B1);
               Aall := Aall * 2 + A;
            end loop;
            Pointer.bval := 0;
         else
            Ball := 0;
            for J in reverse 0 .. Len - 1 loop
               E8_To_VV (Verilog_Wire_Val (Info, J).E8, A, B);
               Aall := Aall * 2 + A;
               Ball := Ball * 2 + B;
            end loop;
            Pointer.bval := Ball;
         end if;

         Pointer.aval := Aall;
         Base := Base + Bits;
         Increment_p_vpi_vecval (Pointer);
      end loop;
   end Vpi_Get_Value_Vecval;

   function Vpi_Get_Value_Range (Expr : vpiHandle) return Integer
   is
      Info : Verilog_Wire_Info;
      Rng : Ghdl_Range_Ptr;
   begin
      Get_Verilog_Wire (Expr.Ref, Info);
      case Info.Vtype is
         when Vcd_Var_Vectors =>
            Rng := Info.Vec_Range;
         when Vcd_Array =>
            declare
               use Grt.Rtis_Addr;
               Arr_Rti : constant Ghdl_Rtin_Type_Array_Acc :=
                 Get_Base_Array_Type (Info.Arr_Rti);
               Rngs : Ghdl_Range_Array (0 .. 0);
            begin
               Bound_To_Range (Info.Arr_Bounds, Arr_Rti, Rngs);
               Rng := Rngs (0);
            end;
         when others =>
            Rng := null;
      end case;
      if Rng /= null then
         if Expr.mType = vpiLeftRange then
            return Integer (Rng.I32.Left);
         else
            return Integer (Rng.I32.Right);
         end if;
      else
         return 0;
      end if;
   end Vpi_Get_Value_Range;

   procedure vpi_get_value (Expr : vpiHandle; Value : p_vpi_value) is
   begin
      if Flag_Trace then
         Trace_Start ("vpi_get_value (");
         Trace (Expr);
         Trace (", {format=");
         Trace_Format (Value.Format);
         Trace ("}) = ");
      end if;

      case Value.Format is
         when vpiObjTypeVal=>
            -- fill in the object type and value:
            -- For an integer, vpiIntVal
            -- For a real, vpiRealVal
            -- For a scalar, either vpiScalar or vpiStrength
            -- For a time variable, vpiTimeVal with vpiSimTime
            -- For a vector, vpiVectorVal
            dbgPut_Line ("vpi_get_value: vpiObjTypeVal");
         when vpiBinStrVal =>
            Value.Str := Vpi_Get_Value_Bin (Expr.Ref);
            --aValue.mStr := NulTerminate2(aExpr.mRef.Name.all);
         when vpiOctStrVal =>
            dbgPut_Line ("vpi_get_value: vpiNet, vpiOctStrVal");
         when vpiDecStrVal =>
            dbgPut_Line ("vpi_get_value: vpiNet, vpiDecStrVal");
         when vpiHexStrVal =>
            dbgPut_Line ("vpi_get_value: vpiNet, vpiHexStrVal");
         when vpiScalarVal =>
            dbgPut_Line ("vpi_get_value: vpiNet, vpiScalarVal");
         when vpiIntVal =>
            case Expr.mType is
               when vpiLeftRange
                  | vpiRightRange =>
                  Value.Integer_m := Vpi_Get_Value_Range (Expr);
               when others =>
                  Value.Integer_m := Integer (Vpi_Get_Value_Int (Expr.Ref));
            end case;
         when vpiRealVal =>     dbgPut_Line ("vpi_get_value: vpiRealVal");
         when vpiStringVal =>   dbgPut_Line ("vpi_get_value: vpiStringVal");
         when vpiTimeVal =>     dbgPut_Line ("vpi_get_value: vpiTimeVal");
         when vpiVectorVal =>
            Vpi_Get_Value_Vecval (Expr.Ref, Value.Vector);
         when vpiStrengthVal => dbgPut_Line ("vpi_get_value: vpiStrengthVal");
         when others =>         dbgPut_Line ("vpi_get_value: unknown mFormat");
      end case;

      if Flag_Trace then
         Trace_Value (Value);
         Trace_Newline;
      end if;
   end vpi_get_value;

   ------------------------------------------------------------------------
   -- void  vpiHandle vpi_put_value(vpiHandle obj, p_vpi_value value,
   --                               p_vpi_time when, int flags)
   -- Alter the simulation value of an object.
   -- see IEEE 1364-2001, chapter 27.14, page 675
   -- FIXME
   type Std_Ulogic_Array is array (Ghdl_Index_Type range <>) of Std_Ulogic;

   procedure Ii_Vpi_Put_Value (Info : Verilog_Wire_Info;
                               Vec : Std_Ulogic_Array;
                               Kind : Force_Kind)
   is
      Mode : Force_Mode;
   begin
      case Info.Val is
         when Vcd_Effective =>
            Mode := Force_Effective;
         when others =>
            --  Force_Driving sets both the driving and the
            --  effective value.
            Mode := Force_Driving;
      end case;

      case Info.Vtype is
         when Vcd_Bad
            | Vcd_Array
            | Vcd_Struct =>
            return;
         when Vcd_Bit
           | Vcd_Bool
           | Vcd_Bitvector =>
            for J in Vec'Range loop
               declare
                  Val : Value_Union;
               begin
                  Val.B1 := Ghdl_B1 (Vec (J) = '1' or Vec (J) = 'H');
                  if Info.Val = Vcd_Variable then
                     Verilog_Wire_Val (Info, J).B1 := Val.B1;
                  else
                     Ghdl_Signal_Force_Any
                       (To_Signal_Arr_Ptr (Info.Ptr)(J), Kind, Mode, Val);
                  end if;
               end;
            end loop;
         when Vcd_Stdlogic
           | Vcd_Stdlogic_Vector =>
            for J in Vec'Range loop
               declare
                  Val : Value_Union;
               begin
                  Val.E8 := Std_Ulogic'Pos (Vec (J));
                  if Info.Val = Vcd_Variable then
                     Verilog_Wire_Val (Info, J).E8 := Val.E8;
                  else
                     Ghdl_Signal_Force_Any
                       (To_Signal_Arr_Ptr (Info.Ptr)(J), Kind, Mode, Val);
                  end if;
               end;
            end loop;
         when Vcd_Enum8 =>
            declare
               V : Value_Union;
            begin
               V.E8 := 0;
               for I in reverse Vec'Range loop
                  if Vec (I) = '1' or Vec (I) = 'H' then
                     --  Ok, handles 'X', 'Z'... like '0'.
                     V.E8 := V.E8 or Shift_Left (1, Natural (Vec'Last - I));
                  end if;
               end loop;
               if Info.Val = Vcd_Variable then
                  Verilog_Wire_Val (Info).E8 := V.E8;
               else
                  Ghdl_Signal_Force_Any
                    (To_Signal_Arr_Ptr (Info.Ptr)(0), Kind, Mode, V);
               end if;
            end;
         when Vcd_Integer32 =>
            declare
               R : Ghdl_U32;
               V : Value_Union;
            begin
               R := 0;
               --  FIXME: what about sign extension ?
               --  FIXME: what about range checks ?
               for I in Vec'Range loop
                  R := Shift_Left (R, 1);
                  if Vec (I) = '1' or Vec (I) = 'H' then
                     --  Ok, handles 'X', 'Z'... like '0'.
                     R := R or 1;
                  end if;
               end loop;
               V.I32 := To_Ghdl_I32 (R);
               if Info.Val = Vcd_Variable then
                  Verilog_Wire_Val (Info).I32 := V.I32;
               else
                  Ghdl_Signal_Force_Any
                    (To_Signal_Arr_Ptr (Info.Ptr)(0), Kind, Mode, V);
               end if;
            end;

         when Vcd_Float64 =>
            null;
      end case;
   end Ii_Vpi_Put_Value;

   procedure Ii_Vpi_Put_Value_Int (Info : Verilog_Wire_Info;
                                   Len  : Ghdl_Index_Type;
                                   Val : Unsigned_32;
                                   Kind : Force_Kind)
   is
      V : Unsigned_32;
      Vec : Std_Ulogic_Array (0 .. Len - 1);
   begin
      V := Val;
      for J in reverse 0 .. Len - 1 loop
         if (V mod 2) = 0 then
            Vec (J) := '0';
         else
            Vec (J) := '1';
         end if;
         V := Shift_Right_Arithmetic (V, 1);
      end loop;
      Ii_Vpi_Put_Value (Info, Vec, Kind);
   end Ii_Vpi_Put_Value_Int;

   procedure Ii_Vpi_Put_Value_Bin_Str (Info : Verilog_Wire_Info;
                                       Len : Ghdl_Index_Type;
                                       Str : Ghdl_C_String;
                                       Kind : Force_Kind)
   is
      Slen : constant Natural := strlen (Str);
      Soff : Integer;
      Vec : Std_Ulogic_Array (0 .. Len - 1);
      V : Std_Ulogic;
   begin
      Soff := Slen;
      for J in reverse 0 .. Len - 1 loop
         Soff := Soff - 1;
         if Soff >= 0 then
            case Str (Str'First + Soff) is
               when 'u' | 'U' => V := 'U';
               when 'x' | 'X' => V := 'X';
               when '0'       => V := '0';
               when '1'       => V := '1';
               when 'z' | 'Z' => V := 'Z';
               when 'w' | 'W' => V := 'W';
               when 'l' | 'L' => V := 'L';
               when 'h' | 'H' => V := 'H';
               when '-'       => V := '-';
               when others    => V := 'U';
            end case;
         else
            V := '0';
         end if;
         Vec (J) := V;
      end loop;
      Ii_Vpi_Put_Value (Info, Vec, Kind);
   end Ii_Vpi_Put_Value_Bin_Str;

   procedure Ii_Vpi_Put_Value_Vecval (Info : Verilog_Wire_Info;
                                      Len  : Ghdl_Index_Type;
                                      Val : p_vpi_vecval;
                                      Kind : Force_Kind)
   is
      Va, Vb : Unsigned_32;
      Vec : Std_Ulogic_Array (0 .. Len - 1);
      Chunks, Bits, Base : Ghdl_Index_Type;
      Pointer : p_vpi_vecval;
   begin
      Chunks := (Len + 31) / 32;
      Pointer := Val;
      Base := 0;

      for I in 0 .. Chunks - 1 loop
         Va := Pointer.aval;
         Vb := Pointer.bval;
         if I < Chunks - 1 then
            Bits := 32;
         else
            Bits := Len mod 32;
         end if;
         for J in 0 .. Bits - 1 loop
            if (Va mod 2) = 0 then
               if (Vb mod 2) = 0 then
                  Vec (Base + J) := '0';
               else
                  Vec (Base + J) := 'Z';
               end if;
            else
               if (Vb mod 2) = 0 then
                  Vec (Base + J) := '1';
               else
                  Vec (Base + J) := 'X';
               end if;
            end if;
            Va := Shift_Right_Arithmetic (Va, 1);
            Vb := Shift_Right_Arithmetic (Vb, 1);
         end loop;
         Base := Base + Bits;
         Increment_p_vpi_vecval (Pointer);
      end loop;
      Ii_Vpi_Put_Value (Info, Vec, Kind);
   end Ii_Vpi_Put_Value_Vecval;

   -- vpiHandle vpi_put_value(vpiHandle obj, p_vpi_value value,
   --                         p_vpi_time when, int flags)
   function vpi_put_value (aObj : vpiHandle;
                           aValue : p_vpi_value;
                           aWhen : p_vpi_time;
                           aFlags : integer) return vpiHandle
   is
      pragma Unreferenced (aWhen);

      Info : Verilog_Wire_Info;
      Len  : Ghdl_Index_Type;
      Kind : Force_Kind;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_put_value (");
         Trace (aObj);
         Trace (", ");
         Trace_Value (aValue);
         Trace (", ");
         Trace_Put_Flags (aFlags);
         Trace (")");
         Trace_Newline;
      end if;

      Reset_Error;

      if aFlags = vpiNoDelay or aFlags = vpiInertialDelay then
         Kind := Deposite;
      elsif aFlags = vpiForceFlag then
         Kind := Force;
      elsif aFlags = vpiReleaseFlag then
         Kind := Release;
      else
         dbgPut_Line ("vpi_put_value: unknown flags");
         return null;
      end if;

      -- A very simple write procedure for VPI.
      -- Basically, it accepts bin_str values, integers and vpiVecval
      -- and converts to appropriate types (only integers, std_logic and
      -- bit values and vectors).

      -- It'll use Set_Effective_Value procedure to update signals

      -- Ignoring aWhen and aFlags, for now.

      -- Check the Obj type.
      -- * The vpiHandle has a reference (field Ref) to a VhpiHandleT
      --   when it doesnt come from a callback.
      case Vhpi_Get_Kind (aObj.Ref) is
         when VhpiPortDeclK
           | VhpiSigDeclK =>
            null;
         when others =>
            return null;
      end case;

      -- The following code segment was copied from the
      -- ii_vpi_get_value function.
      --  Get verilog compat info.
      Get_Verilog_Wire (aObj.Ref, Info);
      if Info.Vtype = Vcd_Bad then
         return null;
      end if;

      Len := Get_Wire_Length (Info);
      if Len = 0 then
         --  No signal.
         return null;
      end if;

      -- Step 1: convert vpi object to internal format.
      --         p_vpi_handle -> Ghdl_Signal_Ptr
      --         To_Signal_Arr_Ptr (Info.Addr) does part of the magic

      -- Step 2: convert datum to appropriate type.
      --         Ghdl_C_String -> Value_Union

      -- Step 3: assigns value to object using Set_Effective_Value
      --         call (from grt-signals)
      -- Set_Effective_Value(sig_ptr, conv_value);

      --  Convert LEN (number of elements) to number of bits.
      case Info.Vtype is
         when Vcd_Bad
            | Vcd_Array
            | Vcd_Struct =>
            dbgPut_Line ("vpi_put_value: bad object kind");
            return null;
         when Vcd_Bit
           | Vcd_Bool
           | Vcd_Bitvector
           | Vcd_Stdlogic
           | Vcd_Stdlogic_Vector =>
            null;
         when Vcd_Enum8 =>
            Len := Len * 8;
         when Vcd_Integer32 =>
            Len := Len * 32;
         when Vcd_Float64 =>
            Len := Len * 64;
      end case;

      -- Checks the format of aValue.
      case aValue.Format is
         when vpiObjTypeVal =>
            dbgPut_Line ("vpi_put_value: vpiObjTypeVal");
         when vpiBinStrVal =>
            Ii_Vpi_Put_Value_Bin_Str (Info, Len, aValue.Str, Kind);
         when vpiOctStrVal =>
            dbgPut_Line ("vpi_put_value: vpiNet, vpiOctStrVal");
         when vpiDecStrVal =>
            dbgPut_Line ("vpi_put_value: vpiNet, vpiDecStrVal");
         when vpiHexStrVal =>
            dbgPut_Line ("vpi_put_value: vpiNet, vpiHexStrVal");
         when vpiScalarVal =>
            dbgPut_Line ("vpi_put_value: vpiNet, vpiScalarVal");
         when vpiIntVal =>
            Ii_Vpi_Put_Value_Int
              (Info, Len, To_Unsigned_32 (aValue.Integer_m), Kind);
         when vpiRealVal =>
            dbgPut_Line("vpi_put_value: vpiRealVal");
         when vpiStringVal =>
            dbgPut_Line("vpi_put_value: vpiStringVal");
         when vpiTimeVal =>
            dbgPut_Line("vpi_put_value: vpiTimeVal");
         when vpiVectorVal =>
            Ii_Vpi_Put_Value_Vecval (Info, Len, aValue.Vector, Kind);
         when vpiStrengthVal =>
            dbgPut_Line("vpi_put_value: vpiStrengthVal");
         when others =>
            dbgPut_Line("vpi_put_value: unknown mFormat");
      end case;

      -- Must return a scheduled event caused by vpi_put_value()
      -- Still dont know how to do it.
      return null;
   end vpi_put_value;

   ------------------------------------------------------------------------
   -- void  vpi_get_time(vpiHandle obj, s_vpi_time*t);
   -- see IEEE 1364-2001, page xxx
   procedure vpi_get_time (Obj: vpiHandle; Time: p_vpi_time)
   is
      function To_Unsigned_64 is
         new Ada.Unchecked_Conversion (Std_Time, Unsigned_64);
      V : Unsigned_64;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_get_time (");
         Trace (Obj);
         Trace (", {mtype=");
         Trace_Time_Tag (Time.mType);
         Trace ("}) = ");
      end if;

      if Obj /= null then
         dbgPut_Line ("vpi_get_time: unhandled");
         return;
      end if;

      V := To_Unsigned_64 (Current_Time);

      case Time.mType is
         when vpiScaledRealTime =>
            Time.mReal := Long_Float (V) * Time_Scale_Unit;
         when vpiSimTime =>
            Time.mHigh := Unsigned_32 (V / 2 ** 32);
            Time.mLow  := Unsigned_32 (V mod 2 ** 32);
         when others =>
            null;
      end case;

      if Flag_Trace then
         Trace_Time (Current_Time);
         Trace_Newline;
      end if;
   end vpi_get_time;

   ------------------------------------------------------------------------

   type Callback_List is record
      First, Last : vpiHandle;
   end record;

   procedure Append_Callback (List : in out Callback_List; Hand : vpiHandle) is
   begin
      if List.First = null then
         List.First := Hand;
      else
         List.Last.Cb_Next := Hand;
         Hand.Cb_Prev := List.Last;
      end if;
      List.Last := Hand;
      Hand.Cb_Next := null;
   end Append_Callback;

   procedure Execute_Callback (Hand : vpiHandle)
   is
      Res : Integer;
      pragma Unreferenced (Res);
   begin
      if Flag_Trace then
         Trace_Start ("vpi call callback ");
         Trace (Hand);
         Trace (" ");
         Trace_Cb_Reason (Hand.Cb.Reason);
         Trace_Newline;
         Trace_Indent := Trace_Indent + 1;
      end if;

      if Hand.Cb.Time /= null then
         -- Supply the current simulation time.
         vpi_get_time (null, Hand.Cb.Time);
      end if;
      Res := Hand.Cb.Cb_Rtn (Hand.Cb'Access);

      if Flag_Trace then
         Trace_Indent := Trace_Indent - 1;
         Trace_Start ("vpi end callback ");
         Trace (Hand);
         Trace_Newline;
      end if;
   end Execute_Callback;

   procedure Execute_Callback_List (List : Callback_List)
   is
      H, Next_H : vpiHandle;
   begin
      H := List.First;
      while H /= null loop
         Next_H := H.Cb_Next;
         --  The callback may destroy h.
         Execute_Callback (H);
         H := Next_H;
      end loop;
   end Execute_Callback_List;

   -- vpiHandle vpi_register_cb(p_cb_data data)
   g_cbEndOfCompile      : Callback_List;
   g_cbStartOfSimulation : Callback_List;
   g_cbEndOfSimulation   : Callback_List;

   function To_Address is new Ada.Unchecked_Conversion
     (vpiHandle, System.Address);

   function To_vpiHandle is new Ada.Unchecked_Conversion
     (System.Address, vpiHandle);

   --  Wrapper
   procedure Call_Callback (Arg : System.Address)
   is
      Hand : vpiHandle;
   begin
      Hand := To_vpiHandle (Arg);

      --  Increase/decrease the reference counter as it is referenced by HAND.
      Hand.Cb_Refcnt := Hand.Cb_Refcnt + 1;
      Execute_Callback (Hand);
      Hand.Cb_Refcnt := Hand.Cb_Refcnt - 1;

      --  Free handlers if called once.
      case Hand.Cb.Reason is
         when cbEndOfCompile
           |  cbStartOfSimulation
           |  cbEndOfSimulation
           |  cbReadOnlySynch
           |  cbReadWriteSynch
           |  cbAfterDelay
           |  cbNextSimTime =>
            pragma Assert (Hand.Cb_Refcnt = 1);
            --  The handler has been removed from the queue, so the reference
            --  counter has to be decremented and its value must be 0.  Time
            --  to free it.
            Free (Hand);
         when others =>
            null;
      end case;
   end Call_Callback;

   procedure Call_Valuechange_Callback (Arg : System.Address)
   is
      Hand : vpiHandle := To_vpiHandle (Arg);
   begin
      if Verilog_Wire_Event (Hand.Cb_Wire) then
         --  Note: the call may remove H from the list, or even
         --  destroy it.
         --  However, we assume it doesn't remove the next callback...

         --  Increase the reference counter as it is referenced by HAND.
         Hand.Cb_Refcnt := Hand.Cb_Refcnt + 1;
         if Hand.Cb.Value /= null then
            -- Supply value before call.  May need to allocate vector space.
            if (Hand.Cb.Value.Format = vpiVectorVal) then
               -- Storage for the vector must be allocated first.
               declare
                  Len : Integer;
               begin
                  Len := Integer ((Get_Wire_Length (Hand.Cb_Wire) + 31) / 32);
                  vpi_vec_callback_helper (Hand.Cb'Access, Len);
                  Hand.Cb_Refcnt := Hand.Cb_Refcnt - 1;
                  --  The handler hasn't been removed from the queue, unless
                  --  the user did it while the callback was executed.
                  --  If so, thereference counter must now be 0
                  --  and we can free it.
                  if Hand.Cb_Refcnt = 0 then
                     Free (Hand);
                  end if;
                  return; -- Callback made.
               end;
            else
               vpi_get_value (Hand.Cb.Obj, Hand.Cb.Value);
            end if;
         end if;
         Execute_Callback (Hand);
         Hand.Cb_Refcnt := Hand.Cb_Refcnt - 1;
         if Hand.Cb_Refcnt = 0 then
            Free (Hand);
         end if;
      end if;
   end Call_Valuechange_Callback;

   procedure Resched_Callback (Arg : System.Address)
   is
      Hand : constant vpiHandle := To_vpiHandle (Arg);
   begin
      case Hand.Cb.Reason is
         when cbReadOnlySynch =>
            Register_Callback
              (Cb_End_Of_Time_Step, Hand.Cb_Handle, Oneshot,
               Call_Callback'Access, Arg);
         when cbReadWriteSynch =>
            Register_Callback
              (Cb_Last_Known_Delta, Hand.Cb_Handle, Oneshot,
               Call_Callback'Access, Arg);
         when others =>
            raise Program_Error;
      end case;
   end Resched_Callback;

   function vpi_register_cb (Data : p_cb_data) return vpiHandle
   is
      Res : vpiHandle;
      T : Std_Time;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_register_cb ({reason=");
         Trace_Cb_Reason (Data.Reason);
         Trace (", obj=");
         Trace (Data.Obj);
         case Data.Reason is
            when cbAfterDelay =>
               Trace (", time=");
               Trace_Time (Vpi_Time_To_Time (Data.Time.all));
            when others =>
               null;
         end case;
         Trace ("}) = ");
      end if;

      Res := new struct_vpiHandle (vpiCallback);
      Res.Cb := Data.all;

      --  There is one reference to the callback as it is registered.
      Res.Cb_Refcnt := 1;

      --  Clear Data when ignored.
      case Data.Reason is
         when cbEndOfCompile
           | cbStartOfSimulation
           | cbEndOfSimulation =>
            --  1364-2005 27.33.3 Simulator action or feature callbacks
            --  The only fields in the s_cb_data structure that need to be
            --  setup for simulation action or feature callbacks are the
            --  reason, cb_rtn and user_data (if desired) fields.
            Res.Cb.Value := null;
            Res.Cb.Time := null;
         when cbReadOnlySynch
           | cbReadWriteSynch
           | cbAfterDelay
           | cbNextSimTime =>
            --  1364-2005 27.33.2 Simulation time callbacks
            --  The value fields are ignored for all reasons with simulation
            --  time callbacks.
            Res.Cb.Value := null;
         when others =>
            null;
      end case;

      --  Copy caller's Time and Value structs.
      if Res.Cb.Time /= null then
         Res.Cb.Time := new s_vpi_time;
         Res.Cb.Time.all := Data.Time.all;
      end if;
      if Res.Cb.Value /= null then
         Res.Cb.Value := new s_vpi_value (Data.Value.Format);
         Res.Cb.Value.all := Data.Value.all;
      end if;

      case Data.Reason is
         when cbEndOfCompile =>
            Append_Callback (g_cbEndOfCompile, Res);
         when cbStartOfSimulation =>
            Append_Callback (g_cbStartOfSimulation, Res);
         when cbEndOfSimulation =>
            Append_Callback (g_cbEndOfSimulation, Res);
         when cbValueChange =>
            Get_Verilog_Wire (Data.Obj.Ref, Res.Cb_Wire);
            Register_Callback
              (Cb_Signals_Updated, Res.Cb_Handle, Repeat,
               Call_Valuechange_Callback'Access, To_Address (Res));
         when cbReadOnlySynch
           | cbReadWriteSynch =>
            T := Vpi_Time_To_Time (Data.Time.all);
            if T = 0 then
               Resched_Callback (To_Address (Res));
            else
               Register_Callback_At
                 (Cb_After_Delay, Res.Cb_Handle, Current_Time + T,
                  Resched_Callback'Access, To_Address (Res));
            end if;
         when cbAfterDelay =>
            T := Vpi_Time_To_Time (Data.Time.all);
            Register_Callback_At
              (Cb_After_Delay, Res.Cb_Handle, Current_Time + T,
               Call_Callback'Access, To_Address (Res));
         when cbNextSimTime =>
            Register_Callback
              (Cb_Next_Time_Step, Res.Cb_Handle, Oneshot,
               Call_Callback'Access, To_Address (Res));
         when others =>
            dbgPut_Line ("vpi_register_cb: unknown callback reason");
            Free (Res);
      end case;

      if Flag_Trace then
         Trace (Res);
         Trace_Newline;
      end if;

      return Res;
   end vpi_register_cb;

   -- int vpi_remove_cb(vpiHandle ref)
   function vpi_remove_cb (Ref : vpiHandle) return Integer
   is
      Ref_Copy : vpiHandle;
      Res : Integer;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_remove_cb (");
         Trace (Ref);
         Trace (") = ");
      end if;

      Res := 1;
      Ref_Copy := Ref;
      case Ref.Cb.Reason is
         when cbValueChange
           |  cbReadWriteSynch
           |  cbReadOnlySynch =>
            Delete_Callback (Ref.Cb_Handle);
         when cbAfterDelay =>
            Unregister_Callback_At (Cb_After_Delay, Ref.Cb_Handle);
         when others =>
            Res := 0;
            Ref_Copy := null;
      end case;

      if Res > 0 then
         Ref.Cb_Refcnt := Ref.Cb_Refcnt - 1;
         if Ref.Cb_Refcnt > 0 then
            --  Do not free REF.
            Ref_Copy := null;
         end if;
      end if;

      if Flag_Trace then
         if Ref_Copy = null then
            Trace ("[not free] ");
         else
            Trace ("[free] ");
         end if;
         Trace (Res);
         Trace_Newline;
      end if;

      Free (Ref_Copy);

      return Res;
   end vpi_remove_cb;

   -- int vpi_free_object(vpiHandle ref)
   function vpi_free_object (aRef: vpiHandle) return integer
   is
      Ref_Copy : vpiHandle;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_free_object (");
         Trace (aRef);
         Trace (")");
         Trace_Newline;
      end if;

      case aRef.mType is
         when vpiCallback =>
            --  Callback are automatically freed.
            null;
         when others =>
            Ref_Copy := aRef;
            Free (Ref_Copy);
      end case;

      return 1;
   end vpi_free_object;

-------------------------------------------------------------------------------
-- * * *   V P I   d u m m i e s   * * * * * * * * * * * * * * * * * * * * * *
-------------------------------------------------------------------------------

   -- int vpi_get_vlog_info(p_vpi_vlog_info vlog_info_p)
   function vpi_get_vlog_info (info : p_vpi_vlog_info) return integer is
      function To_Address is new Ada.Unchecked_Conversion
         (Source => Grt.Options.Argv_Type, Target => System.Address);
   begin
      if Flag_Trace then
         Trace_Start ("vpi_get_vlog_info");
         Trace_Newline;
      end if;

      info.all := (Argc => Options.Argc,
                   Argv => To_Address(Options.Argv),
                   Product => To_Ghdl_C_String (Product'Address),
                   Version => To_Ghdl_C_String (GhdlVersion'Address));
      return 1;
   end vpi_get_vlog_info;

   function Vpi_Handle_By_Index_Internal (Ref: vpiHandle; Index: Integer)
                                         return vpiHandle
   is
      Temp : VhpiHandleT;
      Err : AvhpiErrorT;
   begin
      case Ref.mType is
         when vpiNetArray =>
            Vhpi_Handle_By_Array_Index (Ref.Ref, VhpiIntT (Index), Temp, Err);
            if Err = AvhpiErrorOk then
               --  FIXME: can be an array or a struct.
               return Build_vpiHandle (Temp, vpiNet);
            end if;
         when others =>
            null;
      end case;
      return null;
   end Vpi_Handle_By_Index_Internal;

   function vpi_handle_by_index (Ref : vpiHandle; Index : Integer)
                                return vpiHandle
   is
      Res : vpiHandle;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_handle_by_index (");
         Trace (Ref);
         Trace (", ");
         Trace (Index);
         Trace (") = ");
      end if;

      if Ref = null then
         Res := null;
      else
         Res := Vpi_Handle_By_Index_Internal (Ref, Index);
      end if;

      if Flag_Trace then
         Trace (Res);
         Trace_Newline;
      end if;

      return Res;
   end vpi_handle_by_index;

   --  Return True iff L and R are equal.  L must not have an element set to
   --  NUL.  R must be lower case.
   function Strcasecmp (L : String; R : Ghdl_C_String) return Boolean is
   begin
      if L'Last < L'First - 1 then
         --  Handle null string.
         return R (1) = NUL;
      end if;

      for I in L'Range loop
         if L (I) = NUL then
            --  NUL not allowed in L.
            return False;
         end if;
         if To_Lower (L (I)) /= R (I - L'First + 1) then
            return False;
         end if;
      end loop;

      --  R is NUL terminated.
      return R (L'Length + 1) = NUL;
   end Strcasecmp;

   procedure Find_By_Name (Scope : VhpiHandleT;
                           Rel : VhpiOneToManyT;
                           Name : String;
                           Res : out VhpiHandleT;
                           Err : out AvhpiErrorT)
   is
      It : VhpiHandleT;
      El_Name : Ghdl_C_String;
   begin
      Vhpi_Iterator (Rel, Scope, It, Err);
      if Err /= AvhpiErrorOk then
         return;
      end if;

      loop
         Vhpi_Scan (It, Res, Err);

         --  Either a real error or end of iterator.
         exit when Err /= AvhpiErrorOk;

         El_Name := Avhpi_Get_Base_Name (Res);
         exit when El_Name /= null and then Strcasecmp (Name, El_Name);
      end loop;
   end Find_By_Name;

   function Vpi_Handle_By_Name_Internal
     (Name : Ghdl_C_String; Scope : vpiHandle) return vpiHandle
   is
      B, E : Natural;
      Base, El : VhpiHandleT;
      Err : AvhpiErrorT;
      Escaped : Boolean;
   begin
      --  Extract the start point.
      if Scope = null then
         Get_Root_Scope (Base);
      else
         Base := Scope.Ref;
      end if;

      B := Name'First;

      --  Iterate on each part of Name.
      loop
         exit when Name (B) = NUL;

         --  Extract the next part of the name.
         declare
            C : Character;
         begin
            E := B;
            Escaped := Name (E) = '\';
            loop
               C := Name (E + 1);

               --  '.' is a separator when not inside extended identifiers.
               exit when C = NUL or (C = '.' and not Escaped);

               if C = '\' then
                  --  Start or end of extended identifiers.
                  --  '\' within an extended identifier is doubled, so like
                  --  if there were two extended identifiers.
                  Escaped := not Escaped;
               end if;
               E := E + 1;
            end loop;
         end;

         --  Find name in Base, first as a decl, then as a sub-region.
         Find_By_Name (Base, VhpiDecls, Name (B .. E), El, Err);
         if Err /= AvhpiErrorOk then
            Find_By_Name (Base, VhpiInternalRegions, Name (B .. E), El, Err);
         end if;

         if Err = AvhpiErrorOk then
            --  Found!
            Base := El;
         else
            --  Not found.
            return null;
         end if;

         --  Next path component.
         B := E + 1;
         exit when Name (B) = NUL;
         pragma Assert (Name (B) = '.');
         B := B + 1;
      end loop;

      return Vhpi_Handle_To_Vpi (Base);
   end Vpi_Handle_By_Name_Internal;

   function vpi_handle_by_name (Name : Ghdl_C_String; Scope : vpiHandle)
                               return vpiHandle
   is
      Res : vpiHandle;
   begin
      if Flag_Trace then
         Trace_Start ("vpi_handle_by_name (");
         Trace (Name);
         Trace (", ");
         Trace (Scope);
         Trace (") = ");
      end if;

      Res := Vpi_Handle_By_Name_Internal (Name, Scope);

      if Flag_Trace then
         Trace (Res);
         Trace_Newline;
      end if;

      return Res;
   end vpi_handle_by_name;

   -- unsigned int vpi_mcd_close(unsigned int mcd)
   function vpi_mcd_close (Mcd: integer) return integer
   is
      pragma Unreferenced (Mcd);
   begin
      return 0;
   end vpi_mcd_close;

   -- char *vpi_mcd_name(unsigned int mcd)
   function vpi_mcd_name (Mcd: integer) return integer
   is
      pragma Unreferenced (Mcd);
   begin
      return 0;
   end vpi_mcd_name;

   -- unsigned int vpi_mcd_open(char *name)
   function vpi_mcd_open (Name : Ghdl_C_String) return Integer
   is
      pragma Unreferenced (Name);
   begin
      return 0;
   end vpi_mcd_open;

   function vpi_register_systf (Data : p_vpi_systf_data) return vpiHandle is
   begin
      if Flag_Trace then
         Trace_Start ("vpi_register_systf(");
         Trace (Data.tfname);
         Trace (")");
         Trace_Newline;
      end if;
      return null;
   end vpi_register_systf;

   -- missing here, see grt-cvpi.c:
   --    vpi_mcd_open_x
   --    vpi_mcd_vprintf
   --    vpi_mcd_fputc
   --    vpi_mcd_fgetc
   --    vpi_sim_vcontrol
   --    vpi_chk_error
   --    vpi_handle_by_name

   Default_Message : constant String := "(no error message)" & NUL;
   Unknown_File : constant String := "(no file)" & NUL;

   Err_Message : Ghdl_C_String := To_Ghdl_C_String (Default_Message'Address);
   Err_Code : Ghdl_C_String := null;
   Err_File : Ghdl_C_String := To_Ghdl_C_String (Unknown_File'Address);
   Err_Line : Integer := 0;
   Err_Status : Integer := 0;

   procedure Reset_Error is
   begin
      Err_Message := To_Ghdl_C_String (Default_Message'Address);
      Err_Code := null;
      Err_File := To_Ghdl_C_String (Unknown_File'Address);
      Err_Line := 0;
      Err_Status := 0;
   end Reset_Error;

   function vpi_chk_error (Info : p_vpi_error_info) return Integer is
   begin
      if Info /= null then
         Info.all := (State => vpiRun,
                      Level => vpiError,
                      Message => Err_Message,
                      Product => To_Ghdl_C_String (Product'Address),
                      Code => Err_Code,
                      File => Err_File,
                      Line => Err_Line);
      end if;
      return Err_Status;
   end vpi_chk_error;

   function vpi_control_np (Op : Integer; Status : Integer) return Integer is
   begin
      if Flag_Trace then
         Trace_Start ("vpi_control (");
         Trace_Property (Op);
         Trace (", ");
         Trace (Status);
         Trace (")");
         Trace_Newline;
      end if;

      case Op is
         when vpiFinish
           | vpiStop =>
            Options.Break_Simulation := True;
            return 1;
         when others =>
            return 0;
      end case;
   end vpi_control_np;

------------------------------------------------------------------------------
-- * * *   G H D L   h o o k s   * * * * * * * * * * * * * * * * * * * * * * *
------------------------------------------------------------------------------


   type Lib_Cell;
   type Lib_Access is access Lib_Cell;

   type Lib_Cell is record
      File_Name : String_Access;
      Next : Lib_Access;
   end record;

   Vpi_Libraries : Lib_Access := null;

   ------------------------------------------------------------------------
   --  Return TRUE if OPT is an option for VPI.
   function Vpi_Option (Opt : String) return Boolean
   is
      F : constant Natural := Opt'First;
   begin
      if Opt'Length < 5 or else Opt (F .. F + 4) /= "--vpi" then
         return False;
      end if;
      if Opt'Length > 6 and then Opt (F + 5) = '=' then
         declare
            Lib : Lib_Access;
            File : String_Access;
         begin
            -- Store library info.
            Lib := new Lib_Cell;
            --  Add an extra NUL character.
            File := new String (1 .. Opt'Length - 6 + 1);
            File (1 .. Opt'Length - 6) := Opt (F + 6 .. Opt'Last);
            File (File'Last) := NUL;
            Lib.File_Name := File;

            -- Add new library to the list.
            if Vpi_Libraries = null then
               Vpi_Libraries := Lib;
            else
               declare
                  L : Lib_Access := Vpi_Libraries;
               begin
                  while L.Next /= null loop
                     L := L.Next;
                  end loop;
                  L.Next := Lib;
               end;
            end if;
         end;
         return True;
      elsif Opt'Length >= 11 and then Opt (F + 5 .. F + 10) = "-trace" then
         if Opt'Length > 11 and then Opt (F + 11) = '=' then
            declare
               Filename : String (1 .. Opt'Length - 11);
               Mode : constant String := "wt" & NUL;
            begin
               Filename (1 .. Filename'Last - 1) := Opt (F + 12 .. Opt'Last);
               Filename (Filename'Last) := NUL;
               Trace_File := fopen (Filename'Address, Mode'Address);
               if Trace_File = NULL_Stream then
                  Error_S ("cannot open vpi trace file '");
                  Diag_C (Opt (F + 12 .. Opt'Last));
                  Error_E ("'");
                  return False;
               end if;
            end;
         elsif Opt'Length = 11 then
            Trace_File := stdout;
         else
            Error_S ("incorrect option '");
            Diag_C (Opt);
            Error_E ("'");
            return False;
         end if;
         Flag_Trace := True;
         return True;
      else
         return False;
      end if;
   end Vpi_Option;

   ------------------------------------------------------------------------
   procedure Vpi_Help is
   begin
      Put_Line (" --vpi=FILENAME      load VPI library");
      Put_Line
        (" --vpi-trace[=FILE]  trace vpi calls to stdout or provided FILE");
   end Vpi_Help;

   ------------------------------------------------------------------------
   --  Called before elaboration.

   -- void loadVpiModule(const char* modulename)
   function LoadVpiModule (Filename: Address) return Integer;
   pragma Import (C, LoadVpiModule, "loadVpiModule");

   procedure Vpi_Init
   is
      Lib : Lib_Access := Vpi_Libraries;
   begin
      if Lib = null then
         return;
      end if;
      while Lib /= null loop
         if LoadVpiModule (Lib.File_Name.all'Address) /= 0 then
            Error_S ("cannot load VPI module '");
            Diag_C (Lib.File_Name.all);
            Error_E ("'");
         end if;
         Lib := Lib.Next;
      end loop;
   end Vpi_Init;

   ------------------------------------------------------------------------
   --  Called after elaboration.
   procedure Vpi_Start
   is
      Res : Integer;
      pragma Unreferenced (Res);
   begin
      if Vpi_Libraries = null then
         return;
      end if;

      Grt.Rtis_Types.Search_Types_RTI;
      Execute_Callback_List (g_cbEndOfCompile);
      Execute_Callback_List (g_cbStartOfSimulation);
   end Vpi_Start;

   ------------------------------------------------------------------------
   --  Called at the end of the simulation.
   procedure Vpi_End
   is
      Res : Integer;
      pragma Unreferenced (Res);
   begin
      Execute_Callback_List (g_cbEndOfSimulation);
      Free (Buf_Value);
   end Vpi_End;

   Vpi_Hooks : aliased constant Hooks_Type :=
     (Desc => new String'("vpi: vpi compatible API"),
      Option => Vpi_Option'Access,
      Help => Vpi_Help'Access,
      Init => Vpi_Init'Access,
      Start => Vpi_Start'Access,
      Finish => Vpi_End'Access);

   procedure Register is
   begin
      Register_Hooks (Vpi_Hooks'Access);
   end Register;
end Grt.Vpi;
