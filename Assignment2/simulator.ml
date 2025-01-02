(* X86lite Simulator *)

(* See the documentation in the X86lite specification, available on the 
   course web pages, for a detailed explanation of the instruction
   semantics.
*)

open X86

(* simulator machine state -------------------------------------------------- *)

let mem_bot = 0x400000L          (* lowest valid address *)
let mem_top = 0x410000L          (* one past the last byte in memory *)
let mem_size = Int64.to_int (Int64.sub mem_top mem_bot)
let nregs = 17                   (* including Rip *)
let ins_size = 8L                (* assume we have a 8-byte encoding *)
let exit_addr = 0xfdeadL         (* halt when m.regs(%rip) = exit_addr *)

(* Your simulator should raise this exception if it tries to read from or
   store to an address not within the valid address space. *)
exception X86lite_segfault

(* The simulator memory maps addresses to symbolic bytes.  Symbolic
   bytes are either actual data indicated by the Byte constructor or
   'symbolic instructions' that take up eight bytes for the purposes of
   layout.

   The symbolic bytes abstract away from the details of how
   instructions are represented in memory.  Each instruction takes
   exactly eight consecutive bytes, where the first byte InsB0 stores
   the actual instruction, and the next seven bytes are InsFrag
   elements, which aren't valid data.

   For example, the two-instruction sequence:
        at&t syntax             ocaml syntax
      movq %rdi, (%rsp)       Movq,  [~%Rdi; Ind2 Rsp]
      decq %rdi               Decq,  [~%Rdi]

   is represented by the following elements of the mem array (starting
   at address 0x400000):

       0x400000 :  InsB0 (Movq,  [~%Rdi; Ind2 Rsp])
       0x400001 :  InsFrag
       0x400002 :  InsFrag
       0x400003 :  InsFrag
       0x400004 :  InsFrag
       0x400005 :  InsFrag
       0x400006 :  InsFrag
       0x400007 :  InsFrag
       0x400008 :  InsB0 (Decq,  [~%Rdi])
       0x40000A :  InsFrag
       0x40000B :  InsFrag
       0x40000C :  InsFrag
       0x40000D :  InsFrag
       0x40000E :  InsFrag
       0x40000F :  InsFrag
       0x400010 :  InsFrag
*)
type sbyte = InsB0 of ins       (* 1st byte of an instruction *)
           | InsFrag            (* 2nd - 8th bytes of an instruction *)
           | Byte of char       (* non-instruction byte *)

(* memory maps addresses to symbolic bytes *)
type mem = sbyte array

(* Flags for condition codes *)
type flags = { mutable fo : bool
             ; mutable fs : bool
             ; mutable fz : bool
             }

(* Register files *)
type regs = int64 array

(* Complete machine state *)
type mach = { flags : flags
            ; regs : regs
            ; mem : mem
            }

(* simulator helper functions ----------------------------------------------- *)

(* The index of a register in the regs array *)
let rind : reg -> int = function
  | Rip -> 16
  | Rax -> 0  | Rbx -> 1  | Rcx -> 2  | Rdx -> 3
  | Rsi -> 4  | Rdi -> 5  | Rbp -> 6  | Rsp -> 7
  | R08 -> 8  | R09 -> 9  | R10 -> 10 | R11 -> 11
  | R12 -> 12 | R13 -> 13 | R14 -> 14 | R15 -> 15

(* Helper functions for reading/writing sbytes *)

(* Convert an int64 to its sbyte representation *)
let sbytes_of_int64 (i:int64) : sbyte list =
  let open Char in 
  let open Int64 in
  List.map (fun n -> Byte (shift_right i n |> logand 0xffL |> to_int |> chr))
           [0; 8; 16; 24; 32; 40; 48; 56]

(* Convert an sbyte representation to an int64 *)
let int64_of_sbytes (bs:sbyte list) : int64 =
  let open Char in
  let open Int64 in
  let f b i = match b with
    | Byte c -> logor (shift_left i 8) (c |> code |> of_int)
    | _ -> 0L
  in
  List.fold_right f bs 0L

(* Convert a string to its sbyte representation *)
let sbytes_of_string (s:string) : sbyte list =
  let rec loop acc = function
    | i when i < 0 -> acc
    | i -> loop (Byte s.[i]::acc) (pred i)
  in
  loop [Byte '\x00'] @@ String.length s - 1

(* Serialize an instruction to sbytes *)
let sbytes_of_ins ((op, args):ins) : sbyte list =
  let check = function
    | Imm (Lbl _) | Ind1 (Lbl _) | Ind3 (Lbl _, _) -> 
      invalid_arg "sbytes_of_ins: tried to serialize a label!"
    | o -> ()
  in  
  List.iter check args;
  [InsB0 (op, args); InsFrag; InsFrag; InsFrag;
   InsFrag; InsFrag; InsFrag; InsFrag]

(* Serialize a data element to sbytes *)
let sbytes_of_data : data -> sbyte list = function
  | Quad (Lit i) -> sbytes_of_int64 i
  | Asciz s -> sbytes_of_string s
  | Quad (Lbl _) -> invalid_arg "sbytes_of_data: tried to serialize a label!"



(* It might be useful to toggle printing of intermediate states of your 
   simulator. Our implementation uses this mutable flag to turn on/off
   printing.  For instance, you might write something like:

     [if !debug_simulator then print_endline @@ string_of_ins u; ...]

*)

open Int64_overflow

let debug_simulator = ref false

(* Felt fancy might delete later*)
let xnor (a:bool) (b:bool) : bool = 
  if (a && b) || (not a && not b) then true else false

(* Interpret an opcode with respect to the given flags. *)

(* Interpret a condition code with respect to the given flags. *)
let interp_cnd {fo; fs; fz} : cnd -> bool = 
  fun x ->
    begin match x with
      | Eq  -> if fz then true else false
      | Neq -> if fz then false else true
      | Gt  -> if fz then false else (if (fs = fo) then true else false)
      | Ge  -> if (fs = fo) then true else false
      | Lt  -> if (fs = fo) then false else true
      | Le  -> if fz then true else (if (fs = fo) then false else true)
    end


(* Maps an X86lite address into Some OCaml array index,
   or None if the address is not within the legal address space. *)
let map_addr (addr:quad) : int option = 
  let x = Int64.to_int (Int64.sub addr 0x400000L) in
    if ((x >= mem_size) || (x < 0)) then None else Some x

(* Register Access *)
let read_reg ((m : mach), (r : reg)) : int64 = m.regs.(rind r)

let write_reg ((m : mach), (r : reg), (v : int64)) : unit =
  m.regs.(rind r) <- v; 
  ()

(* Memory Access*)

let get_addr (addr: quad) : int = 
  let addr_val = (map_addr addr) in
  begin match addr_val with
  | Some x -> x
  | None -> (Printf.printf "Get Addr Segfault!\n"); raise X86lite_segfault
  end

let read_mem ((m : mach), (addr : quad)) : sbyte list = 
  Array.to_list(Array.sub m.mem (get_addr addr) 8)
      

let rec write_mem ((m : mach), (addr : quad), (sbs : sbyte list)) : unit =
  begin match sbs with
    | [] -> ()
    | sb::rest -> m.mem.(get_addr addr) <- sb; write_mem (m, (Int64.add addr 1L), rest)
  end


(* Read Address from operand *)
(* Only used for leaq which is dumb *)
let get_op_addr ((m: mach), (op: operand)) : quad = 
  begin match op with
    | Imm i -> 
      begin match i with
        | Lit x -> x
        | Lbl l -> failwith "get_op_addr: label operand not supported"
      end
    | Reg r -> read_reg (m, r)
    | Ind1 imm -> 
      begin match imm with
        | Lit x -> x
        | Lbl _ -> failwith "read_op: label operand not supported in Ind1"
      end
    | Ind2 reg -> (read_reg (m, reg))
    | Ind3 (imm, reg) -> 
      let reg_val =  read_reg (m, reg) in
        begin match imm with
          | Lit imm -> (Int64.add reg_val  imm)
          | Lbl _ -> failwith "get_op_addr: label operand not supported in Ind3"
        end
  end


(* Read value from operand *)

let read_op ((m : mach), (op : operand))  : int64 = 
  begin match op with
    | Imm i -> 
      begin match i with
        | Lit x -> x
        | Lbl l -> failwith "read_op: label operand not supported"
      end
    | Reg r -> read_reg (m, r)
    | Ind1 imm -> 
      begin match imm with
        | Lit x -> int64_of_sbytes (read_mem (m, x))
        | Lbl _ -> failwith "read_op: label operand not supported in Ind1"
      end
    | Ind2 reg -> int64_of_sbytes (read_mem (m, (read_reg (m, reg))))
    | Ind3 (imm, reg) -> 
      let reg_val =  read_reg (m, reg) in
        begin match imm with
          | Lit imm -> int64_of_sbytes (read_mem (m, (Int64.add reg_val imm)))
          | Lbl _ -> failwith "read_op: label operand not supported in Ind3"
        end
  end 

(* Write value to operand *)

let write_op ((m : mach), (op : operand), (value : int64)) : unit =
  begin match op with
    | Imm _ -> failwith "write_op: cannot write to immediate operand"
    | Reg r -> write_reg (m, r, value)
    | Ind1 imm -> 
      begin match imm with
        | Lit x -> (write_mem (m, x, (sbytes_of_int64 value)))
        | Lbl _ -> failwith "read_op: label operand not supported in Ind1"
      end
    | Ind2 reg -> write_mem (m, (read_reg (m, reg)), (sbytes_of_int64 value))
    | Ind3 (imm, reg) -> 
      let reg_val = read_reg (m, reg) in
        begin match imm with
          | Lit imm -> write_mem (m, (Int64.add reg_val  imm), (sbytes_of_int64 value))
        end
  end

(* Fetches the instruction at the given address *)

let fetch_instruction (sbyte : sbyte) : ins = 
  begin match sbyte with
    | InsB0 (op, args) -> (op, args)
    | InsFrag -> failwith "fetch_instruction: expected InsB0, got InsFrag"
    | Byte x -> failwith "fetch_instruction: expected InsB0, got Byte"
  end

(* Performs arithmetic operations and sets overflow flags if wanted*)

let perform_arith (m: mach) (op: opcode) (op1 : int64) (op2 : int64) (setflags : bool): int64 = 
  let {value; overflow} = 
  begin match op with
    | Addq -> add op1 op2
    | Subq -> sub op1 op2
    | Imulq -> mul op1 op2
    | Xorq -> ok (Int64.logxor op1 op2)
    | Orq -> ok (Int64.logor op1 op2)
    | Andq -> ok (Int64.logand op1 op2)
    | Incq -> succ (op1)
    | Decq -> pred (op1)
    | Negq -> neg (op1)
    | Notq -> ok (Int64.lognot op1)
    | _ -> failwith "perform_arith: opcode not supported"
  end in
  if setflags then
    begin
      if overflow then m.flags.fo <- true else m.flags.fo <- false; (* Set Overflow flags*)
      if value = 0L then m.flags.fz <- true else m.flags.fz <- false; (* Set Zero flag*)
      if value < 0L then m.flags.fs <- true else m.flags.fs <- false; (* Set Sign flag*)
    end;
  value (* Returns the result *)

(* Simulates the instruction semantics *)
(* Bundeling similar instructions to minimise code duplication *)
let rec simulate_instruction (m: mach) (op: opcode) (operands : operand list) : unit = 
  begin match op with
    (* In this group no flags have to be set *)
    | Pushq | Popq ->
      begin match operands with
      | src_op :: _ ->
        let src = read_op (m, src_op) in
        begin match op with
        | Pushq -> write_reg (m, Rsp, perform_arith m Subq (read_reg(m, Rsp)) 8L false); write_mem (m, read_reg(m, Rsp), (sbytes_of_int64 src)) 
        | Popq -> write_op(m, src_op, (int64_of_sbytes (read_mem (m, read_reg(m, Rsp))))); write_reg (m, Rsp, perform_arith m Addq (read_reg(m, Rsp)) 8L false) 
        | _ -> failwith "simulate_instruction: Pushq | Popq - you shouldn't be here"
        end
      | _ -> failwith "simulate_instruction: Pushq | Popq - expected at least two operands"
      end
    (* In this group no flags have to be set *)
    | Leaq | Movq -> 
      begin match operands with
      | src_op :: dest_op :: _ ->
        begin match op with
        | Leaq -> write_op (m, dest_op, get_op_addr (m, src_op))
        | Movq -> write_op (m, dest_op, read_op(m, src_op)) 
        | _ -> failwith "simulate_instruction: Leaq | Movq - you shouldn't be here"
        end
      | _ -> failwith "simulate_instruction: Leaq | Movq - expected at least two operands"
      end
    (* In this group flags are already set *)
    | Incq | Decq | Negq | Notq ->
      let set_flag = if op = Notq then false else true in
      begin match operands with
      | src_op :: _ -> write_op (m, src_op, perform_arith m op (read_op(m, src_op)) 0L set_flag)
      | _ -> failwith "simulate_instruction: Incq | Decq | Negq | Notq - expected at least one operand"
      end
    (* In this group flags are already set *)
    | Addq | Subq | Imulq | Xorq | Orq | Andq ->
      begin match operands with
      | src_op :: dest_op :: _ -> write_op (m, dest_op, perform_arith m op (read_op(m, dest_op)) (read_op(m, src_op)) true) (* Should be the same for all of the cased above*)
      | _ -> failwith "simulate_instruction: Addq | Subq | Imulq | Xorq | Orq | Andq - expected at least two operands"
      end
    (* In this group flags are already set *)
    | Shlq | Sarq | Shrq  ->
      begin match operands with
      | amt_op :: dest_op :: _ ->
        let amt = read_op (m, amt_op) in
        let dest = read_op (m, dest_op) in
        let int64_operation = 
          begin match op with
          | Shlq -> Int64.shift_left
          | Sarq -> Int64.shift_right
          | Shrq -> Int64.shift_right_logical
          | _ -> failwith "simulate_instruction: Shlq | Sarq | Shrq - you shouldn't be here"
          end in
          let value = int64_operation dest (Int64.to_int amt) in
          let shifted_val = Int64.shift_right_logical dest 62 in
          if amt = 1L then (* Set Overflow flags*)
            begin match op with
            | Shlq -> if ((Int64.logand (Int64.logxor shifted_val (Int64.shift_right_logical shifted_val 1)) 1L) = 1L) then m.flags.fo <- true else m.flags.fo <- false; 
            | Sarq -> m.flags.fo <- false; 
            | Shrq -> if (Int64.logand (Int64.shift_right_logical dest 63) 1L) = 1L then m.flags.fo <- true else m.flags.fo <- false;
            | _ -> failwith "simulate_instruction: Shlq | Sarq | Shrq - you shouldn't be here"
            end;
          if amt = 0L then () else begin
            if value = 0L then m.flags.fz <- true else m.flags.fz <- false; (* Set Zero flag*)
            if value < 0L then m.flags.fs <- true else m.flags.fs <- false; (* Set Sign flag*)
          end;
          write_op (m, dest_op, value)
      | _ -> failwith "simulate_instruction: Shlq | Sarq | Shrq - expected at least two operands"
      end
    (* In this group no flags have to be set*)
    | Jmp | J _ | Set _ ->
      begin match operands with
      | src_op :: _ ->
        let src = read_op (m, src_op) in
        begin match op with
        | Jmp -> write_reg (m, Rip, src)
        | J c -> if (interp_cnd m.flags c) then write_reg (m, Rip, src) else ()
        | Set c ->  let tmp = (Int64.logand src (Int64.neg 256L)) in let newval = if (interp_cnd m.flags c) then (Int64.logor tmp 1L) else tmp in write_op (m, src_op, newval) (* Set the last BYTE (<- yes BYTE NOT BIT thats over 1hr of my life) of the register to 1 if the condition is met and 0 else*)
        | _ -> failwith "simulate_instruction: Jmp | J | Set - you shouldn't be here"
        end
      | _ -> failwith "simulate_instruction: Jmp | J | Set - expected at least one operand"
      end
    (* In this group flags are already set*)
    | Cmpq ->
      begin match operands with
      | op1 :: op2 :: _ -> ignore (perform_arith m Subq (read_op(m, op2)) (read_op(m, op1)) true) (* Do the subtraction but don't write it back *)
      | _ -> failwith "simulate_instruction: Cmpq - expected at least two operands"
      end
    (* In this group no flags have to be set *)
    | Callq | Retq ->
      begin match op with
      | Callq -> 
        simulate_instruction m Pushq [Reg Rip];
        write_reg (m, Rip, read_op(m, (List.hd operands)))
      | Retq -> simulate_instruction m Popq [Reg Rip]
      | _ -> failwith "simulate_instruction: Callq | Retq - you shouldn't be here"
      end
  end

(* Simulates one step of the machine:
    - fetch the instruction at %rip
    - compute the source and/or destination information from the operands
    - simulate the instruction semantics
    - update the registers and/or memory appropriately
    - set the condition flags
*)

let step (m:mach) : unit = 
  (* get content of %rip*)
  let rip_val = m.regs.(rind Rip) in 
  (* get sbyte from the memory location pointed to by rip*)
  let addr_val = List.hd (read_mem (m, rip_val)) in (* The instruction is only encoded in the first byte of the memory block *)
  (* get instruction from sbyte*)
  let ins = fetch_instruction(addr_val) in 
  if !debug_simulator then Printf.printf "Instruction: %s\n" (string_of_ins ins);
  (* get opcode and arguments from instruction*)
  let (op, args) = ins in 
  (* get operands from arguments*)
  (* update rip to point to the next instruction*)
  m.regs.(rind Rip) <- Int64.add rip_val ins_size; (* This has to be done before simulation since we shouldn't incr after a jmp - like this jmp overrides rip*)
  (* simulate the instruction semantics - this also updates registers & memory - Some flags are updated / some not yet *)
  simulate_instruction m op args;
  ()



(* Runs the machine until the rip register reaches a designated
   memory address. Returns the contents of %rax when the 
   machine halts. *)
let run (m:mach) : int64 =
  if !debug_simulator then print_endline "------------- Starting simulation... --------------\n";
  while m.regs.(rind Rip) <> exit_addr do step m done;
  if !debug_simulator then print_endline "------------- Simulation complete --------------\n";
  m.regs.(rind Rax)
  

(* assembling and linking --------------------------------------------------- *)

(* A representation of the executable *)
type exec = { entry    : quad              (* address of the entry point *)
            ; text_pos : quad              (* starting address of the code *)
            ; data_pos : quad              (* starting address of the data *)
            ; text_seg : sbyte list        (* contents of the text segment *)
            ; data_seg : sbyte list        (* contents of the data segment *)
            }

(* Assemble should raise this when a label is used but not defined *)
exception Undefined_sym of lbl

(* Assemble should raise this when a label is defined more than once *)
exception Redefined_sym of lbl

(* Convert an X86 program into an object file:
   - separate the text and data segments
   - compute the size of each segment
      Note: the size of an Asciz string section is (1 + the string length)
            due to the null terminator

   - resolve the labels to concrete addresses and 'patch' the instructions to 
     replace Lbl values with the corresponding Imm values.

   - the text segment starts at the lowest address
   - the data segment starts after the text segment

  HINT: List.fold_left and List.fold_right are your friends.
 *)


(* Replace all the oparands of type label with the addresses from the symbol table *)
let replace_label_in_instruction (symbol_table: (lbl * quad) list) (ins: ins) : ins = 
  let (op, args) = ins in
  let new_args = List.map (fun arg -> 
    begin match arg with
    | Imm (Lbl l) -> (try Imm (Lit (List.assoc l symbol_table)) with Not_found -> raise (Undefined_sym l))
    | Ind1 (Lbl l) -> (try Ind1 (Lit (List.assoc l symbol_table)) with Not_found -> raise (Undefined_sym l))
    | Ind3 (Lbl l, r) -> (try Ind3 (Lit (List.assoc l symbol_table), r) with Not_found -> raise (Undefined_sym l))
    | _ -> arg
    end) args in
  (op, new_args)

  let replace_label_in_data (symbol_table: (lbl * quad) list) (dat: data) : data = 
    begin match dat with
    | Quad (Lbl l) -> (try Quad (Lit (List.assoc l symbol_table)) with Not_found -> raise (Undefined_sym l))
    | _ -> dat
    end


let assemble (p:prog) : exec =
  (*print_endline ((string_of_prog p) ^ "\n -------------------------- \n");*)
  
  (* The text segment starts at the entry point *)
  let text_pos = 0x400000L in

  let text_seg_with_labels, symbol_table_tmp, text_end_addr = List.fold_left (fun (text_acc,sym_tbl, addr) i -> 
    let {lbl=lbl; global=_; asm=asm} = i in
      begin match asm with
      | Text is -> 
        (* Store the label and its address in the symbol table *)
        let new_sym_tbl = (lbl, addr) :: sym_tbl in
        (* Update the address *)
        let new_addr = Int64.add addr (Int64.mul 8L (Int64.of_int (List.length is))) in
        (* Append the instruction to the text segment *)
        (text_acc @ is, new_sym_tbl, new_addr)
      | Data dat -> (text_acc, sym_tbl, addr)
      end 
    ) ([], [], text_pos) p in

  (* Get the length of all text segments *)
  let text_size = Int64.sub text_end_addr text_pos in
  (* The data segment starts after the text segment *)
  let data_pos = Int64.add text_pos text_size in
  
  let data_seg_with_labels, symbol_table, end_addr = List.fold_left (fun (data_acc,sym_tbl, addr) i -> 
    let {lbl=lbl; global=_; asm=asm} = i in
      begin match asm with
      | Text is -> (data_acc, sym_tbl, addr)
      | Data dat -> 
      (* Store the label and its address in the symbol table *)
      let new_sym_tbl = (lbl, addr) :: sym_tbl in
      (* Update the address *)
      let new_addr = List.fold_left Int64.add addr (List.map (fun d -> 
        begin match d with
        | Asciz s ->  (Int64.of_int (String.length s + 1))
        | Quad _ -> 8L
        end) dat) in
      (* Append the instruction to the text segment *)
      (data_acc @ dat, new_sym_tbl, new_addr)
      end
    ) ([], symbol_table_tmp, text_end_addr) p in


  (* Check if a label is in the symbol table *)
  let list_assoc (lbl: lbl) (lst: (lbl * quad) list) : bool = 
    List.exists (fun (l, _) -> l = lbl) lst in
  (* Check if the main symbol was declared *)
  if (list_assoc "main" symbol_table) then () else raise (Undefined_sym "main");
  (* Check if any symbol was declared more than once *)
  ignore (List.fold_left (fun acc (lbl, rest) -> 
  if (list_assoc lbl acc) then raise (Redefined_sym lbl) else (lbl,rest) :: acc) [] symbol_table);
  
  (* The entry point is the address of the main label *)
  let entry = List.assoc "main" symbol_table in
  (* Concatenate all text segments from the program and replace labels with their addresses from the symbol table *)
  let text_seg =   List.concat_map (fun ins -> sbytes_of_ins (replace_label_in_instruction symbol_table ins)) text_seg_with_labels in
  (* Concatenate all data segments from the program and replace labels with their addresses from the symbol table *)
  let data_seg = List.concat_map (fun dat -> sbytes_of_data (replace_label_in_data symbol_table dat)) data_seg_with_labels in
 
  {entry; text_pos; data_pos; text_seg; data_seg}
        
      
(* Convert an object file into an executable machine state. 
    - allocate the mem array
    - set up the memory state by writing the symbolic bytes to the 
      appropriate locations 
    - create the inital register state
      - initialize rip to the entry point address
      - initializes rsp to the last word in memory 
      - the other registers are initialized to 0
    - the condition code flags start as 'false'

  Hint: The Array.make, Array.blit, and Array.of_list library functions 
  may be of use.
*)


let rec write_mem_addr ((mem : sbyte array), (addr : quad), (sbs : sbyte list)) : unit =
  begin match sbs with
    | [] -> ()
    | sb::rest -> 
      let addr_val = map_addr(addr) in
      begin match addr_val with
        | Some x -> mem.(x) <- sb; write_mem_addr (mem, (Int64.add addr 1L), rest)
        | None -> (Printf.printf "Write Mem Addr Segfault!\n"); raise X86lite_segfault
      end
  end

let load {entry; text_pos; data_pos; text_seg; data_seg} : mach = 
  let mem = (Array.make mem_size (Byte '\x00')) in
  Array.blit (Array.of_list text_seg) 0 mem (get_addr(text_pos)) (List.length text_seg);
  Array.blit (Array.of_list data_seg) 0 mem (get_addr(data_pos)) (List.length data_seg);
  let regs = Array.make nregs 0L in
  regs.(rind Rip) <- entry;
  regs.(rind Rsp) <- Int64.sub mem_top 8L;
  write_mem_addr (mem, (Int64.sub mem_top 8L), (sbytes_of_int64 exit_addr));
  { flags = {fo = false; fs = false; fz = false};
    regs = regs;
    mem = mem
  }
