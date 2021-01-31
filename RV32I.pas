{
  RV32I.pas
    RISC-V RV32I+Mul implementation

    Copyright © 2021 Nicholas Smith

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
}

unit RV32I;

interface

uses
  System.SysUtils;

type
  TRegister = 0..31;

  TRegisterHelper = record helper for TRegister
    function Name:  String;  inline;
    function Saved: Boolean; inline;

    class function Named(AName: String): TRegister; static;
  end;

  TRegisterDesc = record
    Name:  String;
    Saved: Boolean;
  end;

  TOpCode = (
    LUI      = $37,
    AUIPC    = $17,
    JAL      = $6F,
    JALR     = $67,
    BRANCH   = $63,
    LOAD     = $03,
    STORE    = $23,
    OP_IMM   = $13,
    OP       = $33,
    SYS      = $73,
    MISC_MEM = $0F
  );

  TEncoding = (
    U_Type,
    J_Type,
    R_Type,
    I_Type,
    II_Type,
    IS_Type,
    IZ_Type,
    S_Type,
    B_Type
  );

  TFunc3 = 0..7;
  TFunc7 = 0..127;

  TInstrDesc = record
    OpCode:   TOpCode;
    Name:     String;
    Encoding: TEncoding;
    Func3:    TFunc3;
    Func7:    TFunc7;
  end;

  TInstruction = record
    Desc: TInstrDesc;

    RD: TRegister;

    RS1: TRegister;
    RS2: TRegister;

    Imm: UInt32;

    Valid: Boolean;

    class operator Implicit(AInstr: UInt32): TInstruction; // Decode
    class operator Implicit(AInstr: TInstruction): UInt32; // Encode

    class operator Implicit(AInstr: TInstruction): String; // Disassemble
    class operator Implicit(AInstr: String): TInstruction; // Assemble;
  end;

const
  Instructions: array[0..53] of TInstrDesc = (
    (OpCode:LUI;   Name:'LUI';   Encoding:U_Type),
    (OpCode:AUIPC; Name:'AUIPC'; Encoding:U_Type),

    (OpCode:JAL;  Name:'JAL';  Encoding:J_Type),
    (OpCode:JALR; Name:'JALR'; Encoding:I_Type; Func3:0),

    (OpCode:BRANCH; Name:'BEQ';  Encoding:B_Type; Func3:0),
    (OpCode:BRANCH; Name:'BNE';  Encoding:B_Type; Func3:1),
    (OpCode:BRANCH; Name:'BLT';  Encoding:B_Type; Func3:4),
    (OpCode:BRANCH; Name:'BGE';  Encoding:B_Type; Func3:5),
    (OpCode:BRANCH; Name:'BLTU'; Encoding:B_Type; Func3:6),
    (OpCode:BRANCH; Name:'BGEU'; Encoding:B_Type; Func3:7),

    (OpCode:LOAD; Name:'LB';  Encoding:I_Type; Func3:0),
    (OpCode:LOAD; Name:'LH';  Encoding:I_Type; Func3:1),
    (OpCode:LOAD; Name:'LW';  Encoding:I_Type; Func3:2),
    (OpCode:LOAD; Name:'LBU'; Encoding:I_Type; Func3:4),
    (OpCode:LOAD; Name:'LHU'; Encoding:I_Type; Func3:5),

    (OpCode:STORE; Name:'SB'; Encoding:S_Type; Func3:0),
    (OpCode:STORE; Name:'SH'; Encoding:S_Type; Func3:1),
    (OpCode:STORE; Name:'SW'; Encoding:S_Type; Func3:2),

    (OpCode:OP_IMM; Name:'ADDI';  Encoding:II_Type; Func3:0),
    (OpCode:OP_IMM; Name:'SLTI';  Encoding:II_Type; Func3:2),
    (OpCode:OP_IMM; Name:'SLTUI'; Encoding:II_Type; Func3:3),
    (OpCode:OP_IMM; Name:'XORI';  Encoding:II_Type; Func3:4),
    (OpCode:OP_IMM; Name:'ORI';   Encoding:II_Type; Func3:6),
    (OpCode:OP_IMM; Name:'ANDI';  Encoding:II_Type; Func3:7),

    (OpCode:OP_IMM; Name:'SLLI'; Encoding:IS_Type; Func3:1; Func7:0),
    (OpCode:OP_IMM; Name:'SRLI'; Encoding:IS_Type; Func3:5; Func7:0),
    (OpCode:OP_IMM; Name:'SRAI'; Encoding:IS_Type; Func3:5; Func7:32),

    (OpCode:OP; Name:'ADD';  Encoding:R_Type; Func3:0; Func7:0),
    (OpCode:OP; Name:'SUB';  Encoding:R_Type; Func3:0; Func7:32),
    (OpCode:OP; Name:'SLL';  Encoding:R_Type; Func3:1; Func7:0),
    (OpCode:OP; Name:'SLT';  Encoding:R_Type; Func3:2; Func7:0),
    (OpCode:OP; Name:'SLTU'; Encoding:R_Type; Func3:3; Func7:0),
    (OpCode:OP; Name:'XOR';  Encoding:R_Type; Func3:4; Func7:0),
    (OpCode:OP; Name:'SRL';  Encoding:R_Type; Func3:5; Func7:0),
    (OpCode:OP; Name:'SRA';  Encoding:R_Type; Func3:5; Func7:32),
    (OpCode:OP; Name:'OR';   Encoding:R_Type; Func3:6; Func7:0),
    (OpCode:OP; Name:'AND';  Encoding:R_Type; Func3:7; Func7:0),

    (OpCode:OP; Name:'MUL';    Encoding:R_Type; Func3:0; Func7:1),
    (OpCode:OP; Name:'MULH';   Encoding:R_Type; Func3:1; Func7:1),
    (OpCode:OP; Name:'MULHSU'; Encoding:R_Type; Func3:2; Func7:1),
    (OpCode:OP; Name:'MULHU';  Encoding:R_Type; Func3:3; Func7:1),
    (OpCode:OP; Name:'DIV';    Encoding:R_Type; Func3:4; Func7:1),
    (OpCode:OP; Name:'DIVU';   Encoding:R_Type; Func3:5; Func7:1),
    (OpCode:OP; Name:'REM';    Encoding:R_Type; Func3:6; Func7:1),
    (OpCode:OP; Name:'REMU';   Encoding:R_Type; Func3:7; Func7:1),

    (OpCode:SYS; Name:'ECALL';  Encoding:I_Type; Func3:0), // TODO: New encoding
    (OpCode:SYS; Name:'EBREAK'; Encoding:I_Type; Func3:0), //

    (OpCode:SYS; Name:'CSRRW'; Encoding:II_Type; Func3:1),
    (OpCode:SYS; Name:'CSRRS'; Encoding:II_Type; Func3:2),
    (OpCode:SYS; Name:'CSRRC'; Encoding:II_Type; Func3:3),

    (OpCode:SYS; Name:'CSRRWI'; Encoding:IZ_Type; Func3:1),
    (OpCode:SYS; Name:'CSRRSI'; Encoding:IZ_Type; Func3:2),
    (OpCode:SYS; Name:'CSRRCI'; Encoding:IZ_Type; Func3:3),

    (OpCode:MISC_MEM; Name:'FENCE'; Encoding:I_Type; Func3:0) // TODO: New encoding
  );

  Registers: array[TRegister] of TRegisterDesc = (
    (Name:'ZERO'),
    (Name:'RA'),
    (Name:'SP'; Saved:True),
    (Name:'GP'),
    (Name:'TP'),
    (Name:'T0'),
    (Name:'T1'),
    (Name:'T2'),
    (Name:'S0'; Saved:True),
    (Name:'S1'; Saved:True),
    (Name:'A0'),
    (Name:'A1'),
    (Name:'A2'),
    (Name:'A3'),
    (Name:'A4'),
    (Name:'A5'),
    (Name:'A6'),
    (Name:'A7'),
    (Name:'S2';  Saved:True),
    (Name:'S3';  Saved:True),
    (Name:'S4';  Saved:True),
    (Name:'S5';  Saved:True),
    (Name:'S6';  Saved:True),
    (Name:'S7';  Saved:True),
    (Name:'S8';  Saved:True),
    (Name:'S9';  Saved:True),
    (Name:'S10'; Saved:True),
    (Name:'S11'; Saved:True),
    (Name:'T3'),
    (Name:'T$'),
    (Name:'T5'),
    (Name:'T6')
  );

implementation

function TRegisterHelper.Name: String;
begin
  Result := Registers[Self].Name;
end;

function TRegisterHelper.Saved: Boolean;
begin
  Result := Registers[Self].Saved;
end;

class function TRegisterHelper.Named(AName: String): TRegister;
var
  UName: String;
begin
  Result := 0;

  UName := UpperCase(AName).Trim;

  if Length(UName) = 0 then
    Exit; // TODO: raise unknnown register name exception

  if UName[1] = 'X' then
    Exit(StrToInt(UName.Substring(2)));

  for var i := Low(Registers) to High(Registers) do
    if Registers[i].Name = UName then
      Exit(i);
end;

class operator TInstruction.Implicit(AInstr: UInt32): TInstruction;
begin
  Result.Desc.OpCode := TOpCode(AInstr and $7F);

  Result.Desc.Func3 := (AInstr shr 12) and $07;
  Result.Desc.Func7 := (AInstr shr 25) and $7F;

  Result.RD := (AInstr shr  7) and $1F;

  Result.RS1 := (AInstr shr 15) and $1F;
  Result.RS2 := (Ainstr shr 20) and $1F;

  for var Instr in Instructions do
  begin
    if (Instr.OpCode = Result.Desc.OpCode) and
       ((Instr.Encoding in [U_Type, J_Type]) or
       ((Instr.Encoding in [I_Type, II_Type, IZ_Type, S_Type, B_Type]) and (Instr.Func3 = Result.Desc.Func3)) or
       ((Instr.Encoding in [R_Type, IS_Type]) and (Instr.Func3 = Result.Desc.Func3) and (Instr.Func7 = Result.Desc.Func7))) then
    begin
      Result.Desc.Name     := Instr.Name;
      Result.Desc.Encoding := Instr.Encoding;

      Result.Valid := True;

      Break;
    end;
  end;

  if not Result.Valid then
    Exit;

  case Result.Desc.Encoding of
    U_Type:
      Result.Imm := (AInstr and $FFFFF000) shr 12; // Shift?

    J_Type:
    begin
      Result.Imm := ((AInstr shr 11) and $00100000) or
                    ((AInstr shr 30) and $000007FE) or
                    ((AInstr shr  9) and $00000800) or
                    ( AInstr         and $000FF000);

      if (AInstr and $80000000) > 0 then
        Result.Imm := Result.Imm or $FFE00000
      else
        Result.Imm := (Result.Imm shl 11) shr 11;
    end;

    I_Type, II_Type:
    begin
      Result.Imm := AInstr shr 20;

      if (AInstr and $80000000) > 0 then
        Result.Imm := Result.Imm or $FFFFF000;
    end;

    IS_Type:
      Result.Imm := (AInstr shr 20) and $0000001F;

    S_Type:
    begin
      Result.Imm := Result.RD or ((AInstr shr 20) and $00000FE0);


      if (AInstr and $80000000) > 0 then
        Result.Imm := Result.Imm or $FFFFF000
      else
        Result.Imm := (Result.Imm shl 20) shr 20;
    end;

    B_Type:
    begin
      Result.Imm := ((AInstr shr 19) and $00001000) or
                    ((AInstr shr 20) and $000007E0) or
                    ((AInstr shr  7) and $0000001E) or
                    ((AInstr shl  4) and $00000800);

      if (AInstr and $80000000) > 0 then
        Result.Imm := Result.Imm or $FFFFE000
      else
        Result.Imm := (Result.Imm shl 19) shr 19;
    end;
  end;
end;

class operator TInstruction.Implicit(AInstr: TInstruction): UInt32;
begin
  // TODO: Encode the instruction
  Result := 0;
end;

class operator TInstruction.Implicit(AInstr: TInstruction): String;
begin
  if not AInstr.Valid then
    Exit(IntToHex(AInstr));

  Result := AInstr.Desc.Name;

  case AInstr.Desc.Encoding of
    U_Type, J_Type:
      Result := Result + ' ' + AInstr.RD.Name + ', ' + IntToStr(Integer(AInstr.Imm));

    R_Type:
      Result := Result + ' ' + AInstr.RD.Name + ', ' + AInstr.RS1.Name + ', ' + AInstr.RS2.Name;

    I_Type:
      Result := Result + ' ' + AInstr.RD.Name + ', ' + IntToStr(Integer(AInstr.Imm)) + ' (' + AInstr.RS1.Name + ')';

    II_Type, IS_Type:
      Result := Result + ' ' + AInstr.RD.Name + ', ' + AInstr.RS1.Name + ', ' + IntToStr(Integer(AInstr.Imm));

    S_Type:
      Result := Result + ' ' + AInstr.RS2.Name + ', ' + IntToStr(Integer(AInstr.Imm)) + ' (' + AInstr.RS1.Name + ')';

    B_Type:
      Result := Result + ' ' + AInstr.RS1.Name + ', ' + AInstr.RS2.Name + ', ' + IntToStr(Integer(AInstr.Imm));
  end;
end;

class operator TInstruction.Implicit(AInstr: String): TInstruction;
begin
  // TODO: Assemble the instruction
end;

end.

