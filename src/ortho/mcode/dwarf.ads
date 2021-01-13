--  DWARF definitions.
--  Copyright (C) 2006 Tristan Gingold
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
with Interfaces; use Interfaces;

package Dwarf is
   DW_TAG_Array_Type               : constant := 16#01#;
   DW_TAG_Class_Type               : constant := 16#02#;
   DW_TAG_Entry_Point              : constant := 16#03#;
   DW_TAG_Enumeration_Type         : constant := 16#04#;
   DW_TAG_Formal_Parameter         : constant := 16#05#;
   DW_TAG_Imported_Declaration     : constant := 16#08#;
   DW_TAG_Label                    : constant := 16#0a#;
   DW_TAG_Lexical_Block            : constant := 16#0b#;
   DW_TAG_Member                   : constant := 16#0d#;
   DW_TAG_Pointer_Type             : constant := 16#0f#;
   DW_TAG_Reference_Type           : constant := 16#10#;
   DW_TAG_Compile_Unit             : constant := 16#11#;
   DW_TAG_String_Type              : constant := 16#12#;
   DW_TAG_Structure_Type           : constant := 16#13#;
   DW_TAG_Subroutine_Type          : constant := 16#15#;
   DW_TAG_Typedef                  : constant := 16#16#;
   DW_TAG_Union_Type               : constant := 16#17#;
   DW_TAG_Unspecified_Parameters   : constant := 16#18#;
   DW_TAG_Variant                  : constant := 16#19#;
   DW_TAG_Common_Block             : constant := 16#1a#;
   DW_TAG_Common_Inclusion         : constant := 16#1b#;
   DW_TAG_Inheritance              : constant := 16#1c#;
   DW_TAG_Inlined_Subroutine       : constant := 16#1d#;
   DW_TAG_Module                   : constant := 16#1e#;
   DW_TAG_Ptr_To_Member_Type       : constant := 16#1f#;
   DW_TAG_Set_Type                 : constant := 16#20#;
   DW_TAG_Subrange_Type            : constant := 16#21#;
   DW_TAG_With_Stmt                : constant := 16#22#;
   DW_TAG_Access_Declaration       : constant := 16#23#;
   DW_TAG_Base_Type                : constant := 16#24#;
   DW_TAG_Catch_Block              : constant := 16#25#;
   DW_TAG_Const_Type               : constant := 16#26#;
   DW_TAG_Constant                 : constant := 16#27#;
   DW_TAG_Enumerator               : constant := 16#28#;
   DW_TAG_File_Type                : constant := 16#29#;
   DW_TAG_Friend                   : constant := 16#2a#;
   DW_TAG_Namelist                 : constant := 16#2b#;
   DW_TAG_Namelist_Item            : constant := 16#2c#;
   DW_TAG_Packed_Type              : constant := 16#2d#;
   DW_TAG_Subprogram               : constant := 16#2e#;
   DW_TAG_Template_Type_Parameter  : constant := 16#2f#;
   DW_TAG_Template_Value_Parameter : constant := 16#30#;
   DW_TAG_Thrown_Type              : constant := 16#31#;
   DW_TAG_Try_Block                : constant := 16#32#;
   DW_TAG_Variant_Part             : constant := 16#33#;
   DW_TAG_Variable                 : constant := 16#34#;
   DW_TAG_Volatile_Type            : constant := 16#35#;
   DW_TAG_Dwarf_Procedure          : constant := 16#36#;
   DW_TAG_Restrict_Type            : constant := 16#37#;
   DW_TAG_Interface_Type           : constant := 16#38#;
   DW_TAG_Namespace                : constant := 16#39#;
   DW_TAG_Imported_Module          : constant := 16#3a#;
   DW_TAG_Unspecified_Type         : constant := 16#3b#;
   DW_TAG_Partial_Unit             : constant := 16#3c#;
   DW_TAG_Imported_Unit            : constant := 16#3d#;
   DW_TAG_Mutable_Type             : constant := 16#3e#;
   DW_TAG_Lo_User                  : constant := 16#4080#;
   DW_TAG_Hi_User                  : constant := 16#Ffff#;

   DW_CHILDREN_No      : constant := 16#0#;
   DW_CHILDREN_Yes     : constant := 16#1#;

   DW_AT_Sibling              : constant := 16#01#; -- reference
   DW_AT_Location             : constant := 16#02#; -- block, loclistptr
   DW_AT_Name                 : constant := 16#03#; -- string
   DW_AT_Ordering             : constant := 16#09#; -- constant
   DW_AT_Byte_Size            : constant := 16#0b#; -- block, constant, ref
   DW_AT_Bit_Offset           : constant := 16#0c#; -- block, constant, ref
   DW_AT_Bit_Size             : constant := 16#0d#; -- block, constant, ref
   DW_AT_Stmt_List            : constant := 16#10#; -- lineptr
   DW_AT_Low_Pc               : constant := 16#11#; -- address
   DW_AT_High_Pc              : constant := 16#12#; -- address
   DW_AT_Language             : constant := 16#13#; -- constant
   DW_AT_Discr                : constant := 16#15#; -- reference
   DW_AT_Discr_Value          : constant := 16#16#; -- constant
   DW_AT_Visibility           : constant := 16#17#; -- constant
   DW_AT_Import               : constant := 16#18#; -- reference
   DW_AT_String_Length        : constant := 16#19#; -- block, loclistptr
   DW_AT_Common_Reference     : constant := 16#1a#; -- reference
   DW_AT_Comp_Dir             : constant := 16#1b#; -- string
   DW_AT_Const_Value          : constant := 16#1c#; -- block, constant, string
   DW_AT_Containing_Type      : constant := 16#1d#; -- reference
   DW_AT_Default_Value        : constant := 16#1e#; -- reference
   DW_AT_Inline               : constant := 16#20#; -- constant
   DW_AT_Is_Optional          : constant := 16#21#; -- flag
   DW_AT_Lower_Bound          : constant := 16#22#; -- block, constant, ref
   DW_AT_Producer             : constant := 16#25#; -- string
   DW_AT_Prototyped           : constant := 16#27#; -- flag
   DW_AT_Return_Addr          : constant := 16#2a#; -- block, loclistptr
   DW_AT_Start_Scope          : constant := 16#2c#; -- constant
   DW_AT_Stride_Size          : constant := 16#2e#; -- constant
   DW_AT_Upper_Bound          : constant := 16#2f#; -- block, constant, ref
   DW_AT_Abstract_Origin      : constant := 16#31#; -- reference
   DW_AT_Accessibility        : constant := 16#32#; -- constant
   DW_AT_Address_Class        : constant := 16#33#; -- constant
   DW_AT_Artificial           : constant := 16#34#; -- flag
   DW_AT_Base_Types           : constant := 16#35#; -- reference
   DW_AT_Calling_Convention   : constant := 16#36#; -- constant
   DW_AT_Count                : constant := 16#37#; -- block, constant, ref
   DW_AT_Data_Member_Location : constant := 16#38#; -- block, const, loclistptr
   DW_AT_Decl_Column          : constant := 16#39#; -- constant
   DW_AT_Decl_File            : constant := 16#3a#; -- constant
   DW_AT_Decl_Line            : constant := 16#3b#; -- constant
   DW_AT_Declaration          : constant := 16#3c#; -- flag
   DW_AT_Discr_List           : constant := 16#3d#; -- block
   DW_AT_Encoding             : constant := 16#3e#; -- constant
   DW_AT_External             : constant := 16#3f#; -- flag
   DW_AT_Frame_Base           : constant := 16#40#; -- block, loclistptr
   DW_AT_Friend               : constant := 16#41#; -- reference
   DW_AT_Identifier_Case      : constant := 16#42#; -- constant
   DW_AT_Macro_Info           : constant := 16#43#; -- macptr
   DW_AT_Namelist_Item        : constant := 16#44#; -- block
   DW_AT_Priority             : constant := 16#45#; -- reference
   DW_AT_Segment              : constant := 16#46#; -- block, constant
   DW_AT_Specification        : constant := 16#47#; -- reference
   DW_AT_Static_Link          : constant := 16#48#; -- block, loclistptr
   DW_AT_Type                 : constant := 16#49#; -- reference
   DW_AT_Use_Location         : constant := 16#4a#; -- block, loclistptr
   DW_AT_Variable_Parameter   : constant := 16#4b#; -- flag
   DW_AT_Virtuality           : constant := 16#4c#; -- constant
   DW_AT_Vtable_Elem_Location : constant := 16#4d#; -- block, loclistptr
   DW_AT_Allocated            : constant := 16#4e#; -- block, constant, ref
   DW_AT_Associated           : constant := 16#4f#; -- block, constant, ref
   DW_AT_Data_Location        : constant := 16#50#; -- x50block
   DW_AT_Stride               : constant := 16#51#; -- block, constant, ref
   DW_AT_Entry_Pc             : constant := 16#52#; -- address
   DW_AT_Use_UTF8             : constant := 16#53#; -- flag
   DW_AT_Extension            : constant := 16#04#; -- reference
   DW_AT_Ranges               : constant := 16#55#; -- rangelistptr
   DW_AT_Trampoline           : constant := 16#56#; -- address, flag, ref, str
   DW_AT_Call_Column          : constant := 16#57#; -- constant
   DW_AT_Call_File            : constant := 16#58#; -- constant
   DW_AT_Call_Line            : constant := 16#59#; -- constant
   DW_AT_Description          : constant := 16#5a#; -- string
   DW_AT_Lo_User              : constant := 16#2000#; -- ---
   DW_AT_Hi_User              : constant := 16#3fff#; -- ---

   DW_FORM_Addr      : constant := 16#01#; -- address
   DW_FORM_Block2    : constant := 16#03#; -- block
   DW_FORM_Block4    : constant := 16#04#; -- block
   DW_FORM_Data2     : constant := 16#05#; -- constant
   DW_FORM_Data4     : constant := 16#06#; -- constant, lineptr, loclistptr...
   DW_FORM_Data8     : constant := 16#07#; -- ...  macptr, rangelistptr
   DW_FORM_String    : constant := 16#08#; -- string
   DW_FORM_Block     : constant := 16#09#; -- block
   DW_FORM_Block1    : constant := 16#0a#; -- block
   DW_FORM_Data1     : constant := 16#0b#; -- constant
   DW_FORM_Flag      : constant := 16#0c#; -- flag
   DW_FORM_Sdata     : constant := 16#0d#; -- constant
   DW_FORM_Strp      : constant := 16#0e#; -- string
   DW_FORM_Udata     : constant := 16#0f#; -- constant
   DW_FORM_Ref_Addr  : constant := 16#10#; -- reference
   DW_FORM_Ref1      : constant := 16#11#; -- reference
   DW_FORM_Ref2      : constant := 16#12#; -- reference
   DW_FORM_Ref4      : constant := 16#13#; -- reference
   DW_FORM_Ref8      : constant := 16#14#; -- reference
   DW_FORM_Ref_Udata : constant := 16#15#; -- reference
   DW_FORM_Indirect  : constant := 16#16#; -- (see Section 7.5.3)


   DW_OP_Addr        : constant := 16#03#; -- 1 constant address (target spec)
   DW_OP_Deref       : constant := 16#06#; -- 0
   DW_OP_Const1u     : constant := 16#08#; -- 1 1-byte constant
   DW_OP_Const1s     : constant := 16#09#; -- 1 1-byte constant
   DW_OP_Const2u     : constant := 16#0a#; -- 1 2-byte constant
   DW_OP_Const2s     : constant := 16#0b#; -- 1 2-byte constant
   DW_OP_Const4u     : constant := 16#0c#; -- 1 4-byte constant
   DW_OP_Const4s     : constant := 16#0d#; -- 1 4-byte constant
   DW_OP_Const8u     : constant := 16#0e#; -- 1 8-byte constant
   DW_OP_Const8s     : constant := 16#0f#; -- 1 8-byte constant
   DW_OP_Constu      : constant := 16#10#; -- 1 ULEB128 constant
   DW_OP_Consts      : constant := 16#11#; -- 1 SLEB128 constant
   DW_OP_Dup         : constant := 16#12#; -- 0
   DW_OP_Drop        : constant := 16#13#; -- 0
   DW_OP_Over        : constant := 16#14#; -- 0
   DW_OP_Pick        : constant := 16#15#; -- 1 1-byte stack index
   DW_OP_Swap        : constant := 16#16#; -- 0
   DW_OP_Rot         : constant := 16#17#; -- 0
   DW_OP_Xderef      : constant := 16#18#; -- 0
   DW_OP_Abs         : constant := 16#19#; -- 0
   DW_OP_And         : constant := 16#1a#; -- 0
   DW_OP_Div         : constant := 16#1b#; -- 0
   DW_OP_Minus       : constant := 16#1c#; -- 0
   DW_OP_Mod         : constant := 16#1d#; -- 0
   DW_OP_Mul         : constant := 16#1e#; -- 0
   DW_OP_Neg         : constant := 16#1f#; -- 0
   DW_OP_Not         : constant := 16#20#; -- 0
   DW_OP_Or          : constant := 16#21#; -- 0
   DW_OP_Plus        : constant := 16#22#; -- 0
   DW_OP_Plus_Uconst : constant := 16#23#; -- 1 ULEB128 addend
   DW_OP_Shl         : constant := 16#24#; -- 0
   DW_OP_Shr         : constant := 16#25#; -- 0
   DW_OP_Shra        : constant := 16#26#; -- 0
   DW_OP_Xor         : constant := 16#27#; -- 0
   DW_OP_Skip        : constant := 16#2f#; -- 1 signed 2-byte constant
   DW_OP_Bra         : constant := 16#28#; -- 1 signed 2-byte constant
   DW_OP_Eq          : constant := 16#29#; -- 0
   DW_OP_Ge          : constant := 16#2a#; -- 0
   DW_OP_Gt          : constant := 16#2b#; -- 0
   DW_OP_Le          : constant := 16#2c#; -- 0
   DW_OP_Lt          : constant := 16#2d#; -- 0
   DW_OP_Ne          : constant := 16#2e#; -- 0
   DW_OP_Lit0        : constant := 16#30#; -- 0
   DW_OP_Lit1        : constant := 16#31#; -- 0
   DW_OP_Lit2        : constant := 16#32#; -- 0
   DW_OP_Lit3        : constant := 16#33#; -- 0
   DW_OP_Lit4        : constant := 16#34#; -- 0
   DW_OP_Lit5        : constant := 16#35#; -- 0
   DW_OP_Lit6        : constant := 16#36#; -- 0
   DW_OP_Lit7        : constant := 16#37#; -- 0
   DW_OP_Lit8        : constant := 16#38#; -- 0
   DW_OP_Lit9        : constant := 16#39#; -- 0
   DW_OP_Lit10       : constant := 16#3a#; -- 0
   DW_OP_Lit11       : constant := 16#3b#; -- 0
   DW_OP_Lit12       : constant := 16#3c#; -- 0
   DW_OP_Lit13       : constant := 16#3d#; -- 0
   DW_OP_Lit14       : constant := 16#3e#; -- 0
   DW_OP_Lit15       : constant := 16#3f#; -- 0
   DW_OP_Lit16       : constant := 16#40#; -- 0
   DW_OP_Lit17       : constant := 16#41#; -- 0
   DW_OP_Lit18       : constant := 16#42#; -- 0
   DW_OP_Lit19       : constant := 16#43#; -- 0
   DW_OP_Lit20       : constant := 16#44#; -- 0
   DW_OP_Lit21       : constant := 16#45#; -- 0
   DW_OP_Lit22       : constant := 16#46#; -- 0
   DW_OP_Lit23       : constant := 16#47#; -- 0
   DW_OP_Lit24       : constant := 16#48#; -- 0
   DW_OP_Lit25       : constant := 16#49#; -- 0
   DW_OP_Lit26       : constant := 16#4a#; -- 0
   DW_OP_Lit27       : constant := 16#4b#; -- 0
   DW_OP_Lit28       : constant := 16#4c#; -- 0
   DW_OP_Lit29       : constant := 16#4d#; -- 0
   DW_OP_Lit30       : constant := 16#4e#; -- 0
   DW_OP_Lit31       : constant := 16#4f#; -- 0
   DW_OP_Reg0        : constant := 16#50#; -- 0
   DW_OP_Reg1        : constant := 16#51#; -- 0
   DW_OP_Reg2        : constant := 16#52#; -- 0
   DW_OP_Reg3        : constant := 16#53#; -- 0
   DW_OP_Reg4        : constant := 16#54#; -- 0
   DW_OP_Reg5        : constant := 16#55#; -- 0
   DW_OP_Reg6        : constant := 16#56#; -- 0
   DW_OP_Reg7        : constant := 16#57#; -- 0
   DW_OP_Reg8        : constant := 16#58#; -- 0
   DW_OP_Reg9        : constant := 16#59#; -- 0
   DW_OP_Reg10       : constant := 16#5a#; -- 0
   DW_OP_Reg11       : constant := 16#5b#; -- 0
   DW_OP_Reg12       : constant := 16#5c#; -- 0
   DW_OP_Reg13       : constant := 16#5d#; -- 0
   DW_OP_Reg14       : constant := 16#5e#; -- 0
   DW_OP_Reg15       : constant := 16#5f#; -- 0
   DW_OP_Reg16       : constant := 16#60#; -- 0
   DW_OP_Reg17       : constant := 16#61#; -- 0
   DW_OP_Reg18       : constant := 16#62#; -- 0
   DW_OP_Reg19       : constant := 16#63#; -- 0
   DW_OP_Reg20       : constant := 16#64#; -- 0
   DW_OP_Reg21       : constant := 16#65#; -- 0
   DW_OP_Reg22       : constant := 16#66#; -- 0
   DW_OP_Reg23       : constant := 16#67#; -- 0
   DW_OP_Reg24       : constant := 16#68#; -- 0
   DW_OP_Reg25       : constant := 16#69#; -- 0
   DW_OP_Reg26       : constant := 16#6a#; -- 0
   DW_OP_Reg27       : constant := 16#6b#; -- 0
   DW_OP_Reg28       : constant := 16#6c#; -- 0
   DW_OP_Reg29       : constant := 16#6d#; -- 0
   DW_OP_Reg30       : constant := 16#6e#; -- 0
   DW_OP_Reg31       : constant := 16#6f#; -- 0 reg 0..31
   DW_OP_Breg0       : constant := 16#70#; -- 1 SLEB128 offset base reg
   DW_OP_Breg1       : constant := 16#71#; -- 1 SLEB128 offset base reg
   DW_OP_Breg2       : constant := 16#72#; -- 1 SLEB128 offset base reg
   DW_OP_Breg3       : constant := 16#73#; -- 1 SLEB128 offset base reg
   DW_OP_Breg4       : constant := 16#74#; -- 1 SLEB128 offset base reg
   DW_OP_Breg5       : constant := 16#75#; -- 1 SLEB128 offset base reg
   DW_OP_Breg6       : constant := 16#76#; -- 1 SLEB128 offset base reg
   DW_OP_Breg7       : constant := 16#77#; -- 1 SLEB128 offset base reg
   DW_OP_Breg8       : constant := 16#78#; -- 1 SLEB128 offset base reg
   DW_OP_Breg9       : constant := 16#79#; -- 1 SLEB128 offset base reg
   DW_OP_Breg10      : constant := 16#7a#; -- 1 SLEB128 offset base reg
   DW_OP_Breg11      : constant := 16#7b#; -- 1 SLEB128 offset base reg
   DW_OP_Breg12      : constant := 16#7c#; -- 1 SLEB128 offset base reg
   DW_OP_Breg13      : constant := 16#7d#; -- 1 SLEB128 offset base reg
   DW_OP_Breg14      : constant := 16#7e#; -- 1 SLEB128 offset base reg
   DW_OP_Breg15      : constant := 16#7f#; -- 1 SLEB128 offset base reg
   DW_OP_Breg16      : constant := 16#80#; -- 1 SLEB128 offset base reg
   DW_OP_Breg17      : constant := 16#81#; -- 1 SLEB128 offset base reg
   DW_OP_Breg18      : constant := 16#82#; -- 1 SLEB128 offset base reg
   DW_OP_Breg19      : constant := 16#83#; -- 1 SLEB128 offset base reg
   DW_OP_Breg20      : constant := 16#84#; -- 1 SLEB128 offset base reg
   DW_OP_Breg21      : constant := 16#85#; -- 1 SLEB128 offset base reg
   DW_OP_Breg22      : constant := 16#86#; -- 1 SLEB128 offset base reg
   DW_OP_Breg23      : constant := 16#87#; -- 1 SLEB128 offset base reg
   DW_OP_Breg24      : constant := 16#88#; -- 1 SLEB128 offset base reg
   DW_OP_Breg25      : constant := 16#89#; -- 1 SLEB128 offset base reg
   DW_OP_Breg26      : constant := 16#8a#; -- 1 SLEB128 offset base reg
   DW_OP_Breg27      : constant := 16#8b#; -- 1 SLEB128 offset base reg
   DW_OP_Breg28      : constant := 16#8c#; -- 1 SLEB128 offset base reg
   DW_OP_Breg29      : constant := 16#8d#; -- 1 SLEB128 offset base reg
   DW_OP_Breg30      : constant := 16#8e#; -- 1 SLEB128 offset base reg
   DW_OP_Breg31      : constant := 16#8f#; -- 1 SLEB128 offset base reg 0..31
   DW_OP_Regx        : constant := 16#90#; -- 1 ULEB128 register
   DW_OP_Fbreg       : constant := 16#91#; -- 1 SLEB128 offset
   DW_OP_Bregx       : constant := 16#92#; -- 2 ULEB128 reg + SLEB128 offset
   DW_OP_Piece       : constant := 16#93#; -- 1 ULEB128 size of piece addressed
   DW_OP_Deref_Size  : constant := 16#94#; -- 1 1-byte size of data retrieved
   DW_OP_Xderef_Size : constant := 16#95#; -- 1 1-byte size of data retrieved
   DW_OP_Nop         : constant := 16#96#; -- 0
   DW_OP_Push_Object_Address : constant := 16#97#; -- 0
   DW_OP_Call2       : constant := 16#98#; -- 1 2-byte offset of DIE
   DW_OP_Call4       : constant := 16#99#; -- 1 4-byte offset of DIE
   DW_OP_Call_Ref    : constant := 16#9a#; -- 1 4- or 8-byte offset of DIE
   DW_OP_Lo_User     : constant := 16#E0#; --
   DW_OP_Hi_User     : constant := 16#ff#; --

   DW_ATE_Address         : constant := 16#1#;
   DW_ATE_Boolean         : constant := 16#2#;
   DW_ATE_Complex_Float   : constant := 16#3#;
   DW_ATE_Float           : constant := 16#4#;
   DW_ATE_Signed          : constant := 16#5#;
   DW_ATE_Signed_Char     : constant := 16#6#;
   DW_ATE_Unsigned        : constant := 16#7#;
   DW_ATE_Unsigned_Char   : constant := 16#8#;
   DW_ATE_Imaginary_Float : constant := 16#9#;
   DW_ATE_Lo_User         : constant := 16#80#;
   DW_ATE_Hi_User         : constant := 16#ff#;

   DW_ACCESS_Public       : constant := 1;
   DW_ACCESS_Protected    : constant := 2;
   DW_ACCESS_Private      : constant := 3;

   DW_LANG_C89            : constant := 16#0001#;
   DW_LANG_C              : constant := 16#0002#;
   DW_LANG_Ada83          : constant := 16#0003#;
   DW_LANG_C_Plus_Plus    : constant := 16#0004#;
   DW_LANG_Cobol74        : constant := 16#0005#;
   DW_LANG_Cobol85        : constant := 16#0006#;
   DW_LANG_Fortran77      : constant := 16#0007#;
   DW_LANG_Fortran90      : constant := 16#0008#;
   DW_LANG_Pascal83       : constant := 16#0009#;
   DW_LANG_Modula2        : constant := 16#000a#;
   DW_LANG_Java           : constant := 16#000b#;
   DW_LANG_C99            : constant := 16#000c#;
   DW_LANG_Ada95          : constant := 16#000d#;
   DW_LANG_Fortran95      : constant := 16#000e#;
   DW_LANG_PLI            : constant := 16#000f#;
   DW_LANG_Lo_User        : constant := 16#8000#;
   DW_LANG_Hi_User        : constant := 16#ffff#;

   DW_ID_Case_Sensitive   : constant := 0;
   DW_ID_Up_Case          : constant := 1;
   DW_ID_Down_Case        : constant := 2;
   DW_ID_Case_Insensitive : constant := 3;

   DW_CC_Normal           : constant := 16#1#;
   DW_CC_Program          : constant := 16#2#;
   DW_CC_Nocall           : constant := 16#3#;
   DW_CC_Lo_User          : constant := 16#40#;
   DW_CC_Hi_User          : constant := 16#Ff#;

   DW_INL_Not_Inlined          : constant := 0;
   DW_INL_Inlined              : constant := 1;
   DW_INL_Declared_Not_Inlined : constant := 2;
   DW_INL_Declared_Inlined     : constant := 3;

   --  Line number information.
   --  Line number standard opcode.
   DW_LNS_Copy               : constant Unsigned_8 := 1;
   DW_LNS_Advance_Pc         : constant Unsigned_8 := 2;
   DW_LNS_Advance_Line       : constant Unsigned_8 := 3;
   DW_LNS_Set_File           : constant Unsigned_8 := 4;
   DW_LNS_Set_Column         : constant Unsigned_8 := 5;
   DW_LNS_Negate_Stmt        : constant Unsigned_8 := 6;
   DW_LNS_Set_Basic_Block    : constant Unsigned_8 := 7;
   DW_LNS_Const_Add_Pc       : constant Unsigned_8 := 8;
   DW_LNS_Fixed_Advance_Pc   : constant Unsigned_8 := 9;
   DW_LNS_Set_Prologue_End   : constant Unsigned_8 := 10;
   DW_LNS_Set_Epilogue_Begin : constant Unsigned_8 := 11;
   DW_LNS_Set_Isa            : constant Unsigned_8 := 12;

   --  Line number extended opcode.
   --  Encoding is 0:Len:LNE_OP:data
   DW_LNE_End_Sequence       : constant Unsigned_8 := 1;
   DW_LNE_Set_Address        : constant Unsigned_8 := 2;
   DW_LNE_Define_File        : constant Unsigned_8 := 3;
   DW_LNE_Lo_User            : constant Unsigned_8 := 128;
   DW_LNE_Hi_User            : constant Unsigned_8 := 255;

   DW_CFA_Advance_Loc        : constant Unsigned_8 := 16#40#;
   DW_CFA_Advance_Loc_Min    : constant Unsigned_8 := 16#40#;
   DW_CFA_Advance_Loc_Max    : constant Unsigned_8 := 16#7f#;
   DW_CFA_Offset             : constant Unsigned_8 := 16#80#;
   DW_CFA_Offset_Min         : constant Unsigned_8 := 16#80#;
   DW_CFA_Offset_Max         : constant Unsigned_8 := 16#Bf#;
   DW_CFA_Restore            : constant Unsigned_8 := 16#C0#;
   DW_CFA_Restore_Min        : constant Unsigned_8 := 16#C0#;
   DW_CFA_Restore_Max        : constant Unsigned_8 := 16#FF#;
   DW_CFA_Nop                : constant Unsigned_8 := 16#00#;
   DW_CFA_Set_Loc            : constant Unsigned_8 := 16#01#;
   DW_CFA_Advance_Loc1       : constant Unsigned_8 := 16#02#;
   DW_CFA_Advance_Loc2       : constant Unsigned_8 := 16#03#;
   DW_CFA_Advance_Loc4       : constant Unsigned_8 := 16#04#;
   DW_CFA_Offset_Extended    : constant Unsigned_8 := 16#05#;
   DW_CFA_Restore_Extended   : constant Unsigned_8 := 16#06#;
   DW_CFA_Undefined          : constant Unsigned_8 := 16#07#;
   DW_CFA_Same_Value         : constant Unsigned_8 := 16#08#;
   DW_CFA_Register           : constant Unsigned_8 := 16#09#;
   DW_CFA_Remember_State     : constant Unsigned_8 := 16#0a#;
   DW_CFA_Restore_State      : constant Unsigned_8 := 16#0b#;
   DW_CFA_Def_Cfa            : constant Unsigned_8 := 16#0c#;
   DW_CFA_Def_Cfa_Register   : constant Unsigned_8 := 16#0d#;
   DW_CFA_Def_Cfa_Offset     : constant Unsigned_8 := 16#0e#;
   DW_CFA_Def_Cfa_Expression : constant Unsigned_8 := 16#0f#;

   DW_EH_PE_Omit    : constant Unsigned_8 := 16#Ff#;
   DW_EH_PE_Uleb128 : constant Unsigned_8 := 16#01#;
   DW_EH_PE_Udata2  : constant Unsigned_8 := 16#02#;
   DW_EH_PE_Udata4  : constant Unsigned_8 := 16#03#;
   DW_EH_PE_Udata8  : constant Unsigned_8 := 16#04#;
   DW_EH_PE_Sleb128 : constant Unsigned_8 := 16#09#;
   DW_EH_PE_Sdata2  : constant Unsigned_8 := 16#0A#;
   DW_EH_PE_Sdata4  : constant Unsigned_8 := 16#0B#;
   DW_EH_PE_Sdata8  : constant Unsigned_8 := 16#0C#;
   DW_EH_PE_Absptr  : constant Unsigned_8 := 16#00#;
   DW_EH_PE_Pcrel   : constant Unsigned_8 := 16#10#;
   DW_EH_PE_Datarel : constant Unsigned_8 := 16#30#;
   DW_EH_PE_Format_Mask : constant Unsigned_8 := 16#0f#;
end Dwarf;
