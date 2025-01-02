(* ll ir compilation -------------------------------------------------------- *)

open Ll
open X86

(* Overview ----------------------------------------------------------------- *)

(* We suggest that you spend some time understanding this entire file and
   how it fits with the compiler pipeline before making changes.  The suggested
   plan for implementing the compiler is provided on the project web page.
*)

(* Debug value - set true to enable debug mode *)
let debug = false


(* helpers ------------------------------------------------------------------ *)

(* useful for looking up items in tdecls or layouts *)
let lookup x m =
  try
    List.assoc x m
  with
  | Not_found -> failwith ("Custom lookup function: Key not found in the map")

(* Take the first n elements of a list *)
let rec take n lst =
  match n, lst with
  | 0, _ | _, [] -> []
  | n, x :: xs -> x :: take (n - 1) xs

(* Map LL comparison operations to X86 condition codes *)
let compile_cnd : Ll.cnd -> X86.cnd = function
  | Ll.Eq  -> X86.Eq
  | Ll.Ne  -> X86.Neq
  | Ll.Slt -> X86.Lt
  | Ll.Sle -> X86.Le
  | Ll.Sgt -> X86.Gt
  | Ll.Sge -> X86.Ge

let compile_binop : Ll.bop -> X86.opcode = function
  | Ll.Add  -> X86.Addq
  | Ll.Sub  -> X86.Subq
  | Ll.Mul  -> X86.Imulq
  | Ll.Shl  -> X86.Shlq
  | Ll.Lshr -> X86.Shrq
  | Ll.Ashr -> X86.Sarq
  | Ll.And  -> X86.Andq
  | Ll.Or   -> X86.Orq
  | Ll.Xor  -> X86.Xorq

(* Compile a LL type to an X86 operand size *)



(* locals and layout -------------------------------------------------------- *)

(* One key problem in compiling the LLVM IR is how to map its local
   identifiers to X86 abstractions.  For the best performance, one
   would want to use an X86 register for each LLVM %uid.  However,
   since there are an unlimited number of %uids and only 16 registers,
   doing so effectively is quite difficult.  We will see later in the
   course how _register allocation_ algorithms can do a good job at
   this.

   A simpler, but less performant, implementation is to map each %uid
   in the LLVM source to a _stack slot_ (i.e. a region of memory in
   the stack).  Since LLVMlite, unlike real LLVM, permits %uid locals
   to store only 64-bit data, each stack slot is an 8-byte value.

   [ NOTE: For compiling LLVMlite, even i1 data values should be represented
   in 64 bit. This greatly simplifies code generation. ]

   We call the datastructure that maps each %uid to its stack slot a
   'stack layout'.  A stack layout maps a uid to an X86 operand for
   accessing its contents.  For this compilation strategy, the operand
   is always an offset from %rbp (in bytes) that represents a storage slot in
   the stack.
*)

type layout = (uid * X86.operand) list  (* list of tuples with uid and X86.operand as elements*)

(* A context contains the global type declarations (needed for getelementptr
   calculations) and a stack layout. *)
type ctxt = { tdecls : (tid * ty) list
            ; layout : layout
            }

(* compiling operands  ------------------------------------------------------ *)

(* LLVM IR instructions support several kinds of operands.

   LL local %uids live in stack slots, whereas global ids live at
   global addresses that must be computed from a label.  Constants are
   immediately available, and the operand Null is the 64-bit 0 value.

     NOTE: two important facts about global identifiers:

     (1) You should use (Platform.mangle gid) to obtain a string
     suitable for naming a global label on your platform (OS X expects
     "_main" while linux expects "main").

     (2) 64-bit assembly labels are not allowed as immediate operands.
     That is, the X86 code: movq _gid %rax which looks like it should
     put the address denoted by _gid into %rax is not allowed.
     Instead, you need to compute an %rip-relative address using the
     leaq instruction:   leaq _gid(%rip).

   One strategy for compiling instruction operands is to use a
   designated register (or registers) for holding the values being
   manipulated by the LLVM IR instruction. You might find it useful to
   implement the following helper function, whose job is to generate
   the X86 instruction that moves an LLVM operand into a designated
   destination (usually a register).
*)
let compile_operand (ctxt:ctxt) (dest:X86.operand) : Ll.operand -> X86.ins =
  function
  | Ll.Id uid -> 
      let src = lookup uid ctxt.layout in (* Look up the stack slot for the local variable in the layout *)
      X86.Movq, [src; dest] (* Move the value from the stack slot to the destination *)
  | Ll.Gid gid -> 
      X86.Leaq, [Ind3 (Lbl (Platform.mangle gid), Rip); dest] (* Load the address of the global variable into the destination *)
  | Ll.Const c ->
      X86.Movq, [Imm (Lit c); dest] (* Move the constant value into the destination *)
  | Ll.Null ->
      X86.Movq, [Imm (Lit 0L); dest] (* Move the 64-bit null (0) into the destination *)


(* compiling call  ---------------------------------------------------------- *)

(* You will probably find it helpful to implement a helper function that
   generates code for the LLVM IR call instruction.

   The code you generate should follow the x64 System V AMD64 ABI
   calling conventions, which places the first six 64-bit (or smaller)
   values in registers and pushes the rest onto the stack.  Note that,
   since all LLVM IR operands are 64-bit values, the first six
   operands will always be placed in registers.  (See the notes about
   compiling fdecl below.)

   [ NOTE: It is the caller's responsibility to clean up arguments
   pushed onto the stack, so you must free the stack space after the
   call returns. ]

   [ NOTE: Don't forget to preserve caller-save registers (only if
   needed). ]
*)

let arg_regs = [Rdi; Rsi; Rdx; Rcx; R08; R09]

 (* Compile each argument into the appropriate location *)
let rec compile_args (ctxt:ctxt) (compiled_args:X86.ins list) (stack_offset:int) (args:(Ll.ty * Ll.operand) list) (arg_num:int) : X86.ins list * int =
  match args with
  | [] -> (compiled_args, stack_offset)
  | (ty, op) :: rest ->
      if arg_num < 6 then
        (* If we have less than 6 arguments, move them into the appropriate register *)
        let arg_reg = List.nth arg_regs arg_num in
        (* Compile the argument and move it into the register *)
        let arg_ins = compile_operand ctxt (Reg arg_reg) op in
        (* Recursively compile the rest of the arguments *)
        compile_args (ctxt) (arg_ins :: compiled_args) stack_offset rest (arg_num + 1)
      else
        (* If we have more than 6 arguments, push the rest onto the stack *)
        let arg_ins = compile_operand ctxt (Reg Rax) op in
        (* Push the argument onto the stack *)
        let push_ins = X86.Pushq, [Reg Rax] in
        (* Update the stack offset *)
        let new_stack_offset = stack_offset + 8 in (*It is technically "- 8" but this prevents double negation *)
        (* Recursively compile the rest of the arguments *)
        compile_args (ctxt) (arg_ins :: push_ins :: compiled_args) new_stack_offset rest (arg_num + 1)


(* Compile the function to call *)
let fn_call ctxt (fn:Ll.operand) : X86.ins list =
  if debug then Printf.printf "Calling function %s\n" (Llutil.string_of_operand fn);
  match fn with
  | Ll.Gid gid -> [X86.Callq, [Imm(Lbl (Platform.mangle gid))]]
  | Ll.Id uid  -> let ins = compile_operand ctxt (Reg Rax) (Ll.Id uid) in
                  [ins; X86.Callq, [Reg Rax]]
  | _ -> failwith "Unsupported function operand"

(* Clean up the stack if we pushed arguments onto it and restore register values we saved *)
let cleanup_stack (stack_offset:int) : X86.ins list =
  if debug then Printf.printf "Stack offset: %d\n" stack_offset;
  (* Restore the stack pointer *)
  if stack_offset > 0 then
    [(X86.Addq, [Imm (Lit (Int64.of_int stack_offset)); Reg Rsp])]
  else
    []

(* Move return value from Rax to dest *)
let handle_return (dest: X86.operand option) : X86.ins list =
  match dest with
  | Some d -> [X86.Movq, [Reg Rax; d]]
  | None   -> []

let compile_call (ctxt:ctxt) (dest:X86.operand option) (fn:Ll.operand) (args:(Ll.ty * Ll.operand) list) : X86.ins list =
  (* Compile the arguments and keep track of how much stack space we use *)
  let num_args = List.length args in
  (* Save the register values we will use for arguments *)
  let save_regs = List.map (fun reg -> (X86.Pushq, [Reg reg])) (take num_args arg_regs) in
  (* Compile the arguments into registers / stack *)
  let arg_ins, stack_offset = compile_args ctxt [] 0 args 0 in 
  (* Compile the function call, clean up the stack, and handle the return value *)
  let fn_call_ins = fn_call ctxt fn in
  (* Cleanup the stack in case we pushed arguments *)
  let cleanup_ins = cleanup_stack stack_offset in
  (* Restore the register values pushed onto the stack *)
  let restore_regs : X86.ins list = List.map (fun reg -> (X86.Popq, [Reg reg])) (List.rev (take num_args arg_regs)) in
  (* Move the return value to the destination *)
  let return_ins = handle_return dest in
  (* The final compiled instructions *)
  save_regs @ arg_ins @ fn_call_ins @ cleanup_ins @ restore_regs @ return_ins
  


(* compiling getelementptr (gep)  ------------------------------------------- *)

(* The getelementptr instruction computes an address by indexing into
   a datastructure, following a path of offsets.  It computes the
   address based on the size of the data, which is dictated by the
   data's type.

   To compile getelementptr, you must generate x86 code that performs
   the appropriate arithmetic calculations.
*)

(* [size_ty] maps an LLVMlite type to a size in bytes.
    (needed for getelementptr)

   - the size of a struct is the sum of the sizes of each component
   - the size of an array of t's with n elements is n * the size of t
   - all pointers, I1, and I64 are 8 bytes
   - the size of a named type is the size of its definition

   - Void, i8, and functions have undefined sizes according to LLVMlite.
     Your function should simply return 0 in those cases
*)


(* size_ty: computes the size in bytes of a given LLVMlite type. *)
let rec size_ty (tdecls:(tid * ty) list) (t:Ll.ty) : int =
  match t with
  | I1 -> 8  (* 1-bit integers are stored as 64-bit values *)
  | I8 -> 1  (* 8-bit integers *)
  | I64 -> 8 (* 64-bit integers *)
  | Ptr _ -> 8  (* pointers are 64-bit *)
  | Struct ts -> 
      List.fold_left (fun acc ty -> acc + size_ty tdecls ty) 0 ts (* sum of the sizes of the struct elements *)
  | Array (n, ty) -> n * size_ty tdecls ty (* n times the size of the array element *)
  | Namedt tid -> 
      (try size_ty tdecls (lookup tid tdecls) 
       with Not_found -> failwith ("Type " ^ tid ^ " not found"))
  | Fun _ -> 0  (* functions have no size *)
  | Void -> 0   (* void has no size *)

  

(* Generates code that computes a pointer value.

   1. op must be of pointer type: t*

   2. the value of op is the base address of the calculation

   3. the first index in the path is treated as the index into an array
     of elements of type t located at the base address

   4. subsequent indices are interpreted according to the type t:

     - if t is a struct, the index must be a constant n and it
       picks out the n'th element of the struct. [ NOTE: the offset
       within the struct of the n'th element is determined by the
       sizes of the types of the previous elements ]

     - if t is an array, the index can be any operand, and its
       value determines the offset within the array.

     - if t is any other type, the path is invalid

   5. if the index is valid, the remainder of the path is computed as
      in (4), but relative to the type f the sub-element picked out
      by the path so far
*)

(* Helper to compute the size of a type *)
let rec compute_offset (ctxt:ctxt) (ty : Ll.ty) (index : Ll.operand) (offset_insns : X86.ins list): (X86.ins list * Ll.ty)  =
  match ty with
  | Ll.Struct tys ->
      begin match index with
      | Ll.Const n ->
          (* For struct, the index must be a constant *)
          let element_size = List.fold_left (fun acc t -> acc + size_ty ctxt.tdecls t) 0 (take (Int64.to_int n) tys) in
          (* Add the size of the struct element to the offset *)
          let add_ins = [X86.Addq, [Imm (Lit (Int64.of_int element_size)); Reg Rax]] in
          (* Return the size so far, and the remaining type *)
          (offset_insns @ add_ins, List.nth tys (Int64.to_int n))
      | _ -> failwith "compute_offset: Struct index must be a constant"
      end
  | Ll.Array (_, elt_ty) | Ll.Ptr elt_ty -> 
      (* For arrays and pointers, the index can be any operand *)
      let elt_size = size_ty ctxt.tdecls elt_ty in
      let op_ins = compile_operand ctxt (Reg Rbx) index in
      (* Multiply the index by the size of the array element *)
      let mul_ins = X86.Imulq, [Imm (Lit (Int64.of_int elt_size)); Reg Rbx] in
      (* Add the offset to the base address *)
      let add_ins = [X86.Addq, [Reg Rbx; Reg Rax]] in
      (offset_insns @ (op_ins :: mul_ins :: add_ins), elt_ty)
  | Ll.Namedt x -> compute_offset ctxt (lookup x ctxt.tdecls) index offset_insns
  | _ as unsupported_type -> 
      let ty_str = Llutil.string_of_ty unsupported_type in
      failwith ("compute_offset: Unsupported type for GEP: " ^ ty_str)


let compile_gep (ctxt:ctxt) (op: Ll.ty * Ll.operand) (path: Ll.operand list) : X86.ins list =
  if debug then Printf.printf "Compiling GEP: op = %s, path = %s\n" (Llutil.string_of_operand (snd op)) (String.concat "," (List.map Llutil.string_of_operand path));
  let (base_ty, base_op) = op in
  (* Compile the base operand *)
  let base_ins = [compile_operand ctxt (Reg Rax) base_op] in
  (* Process each index in the path *)
  let rec process_path (current_ty: Ll.ty) (remaining_path: Ll.operand list) (offset_insns : X86.ins list) =
    match remaining_path with
    | [] -> offset_insns (* No more indices to process *)
    | idx :: rest ->
        (* Compute the offset for the current index *)
        let (new_offset_insns, next_ty) = compute_offset ctxt current_ty idx offset_insns in
        (* Recursively process the rest of the path *)
        process_path next_ty rest new_offset_insns
  in
  process_path base_ty path base_ins
  





(* compiling instructions  -------------------------------------------------- *)

(* The result of compiling a single LLVM instruction might be many x86
   instructions.  We have not determined the structure of this code
   for you. Some of the instructions require only a couple of assembly
   instructions, while others require more.  We have suggested that
   you need at least compile_operand, compile_call, and compile_gep
   helpers; you may introduce more as you see fit.

   Here are a few notes:

   - Icmp:  the Setb instruction may be of use.  Depending on how you
     compile Cbr, you may want to ensure that the value produced by
     Icmp is exactly 0 or 1.

   - Load & Store: these need to dereference the pointers. Const and
     Null operands aren't valid pointers.  Don't forget to
     Platform.mangle the global identifier.

   - Alloca: needs to return a pointer into the stack

   - Bitcast: does nothing interesting at the assembly level
*)
let compile_insn (ctxt:ctxt) ((uid:uid), (i:Ll.insn)) : X86.ins list =
  if debug then Printf.printf "Compiling instruction %s\n" (Llutil.string_of_insn i);
  match i with
  | Binop (bop, ty, op1, op2) ->
    let dest = lookup uid ctxt.layout in
    begin match bop with
    | Ll.Shl | Ll.Lshr | Ll.Ashr -> 
      (* Shift operations require the shift amount to be in the %rcx register *)
      let push_rcx = X86.Pushq, [Reg Rcx] in
      let op1_ins = compile_operand ctxt (Reg Rax) op1 in
      let op2_ins = compile_operand ctxt (Reg Rcx) op2 in
      let binop_ins = compile_binop bop, [Reg Rcx; Reg Rax] in 
      let mov_ins = X86.Movq, [Reg Rax; dest] in
      let pop_rcx = X86.Popq, [Reg Rcx] in
      [push_rcx; op1_ins; op2_ins; binop_ins; mov_ins; pop_rcx]
    | _ -> 
      let op1_ins = compile_operand ctxt (Reg Rax) op1 in
      let op2_ins = compile_operand ctxt (Reg Rbx) op2 in
      let binop_ins = compile_binop bop, [Reg Rbx; Reg Rax] in
      let mov_ins = X86.Movq, [Reg Rax; dest] in
      [op1_ins; op2_ins; binop_ins; mov_ins]
    end
  | Alloca ty -> 
    (* Allocate space on the stack for the local variable and load the pointer into dest*)
    let dest = lookup uid ctxt.layout in
    let sub_rsp_ins = X86.Subq, [Imm (Lit 8L); Reg Rsp] in
    let mov_ins = X86.Movq, [Reg Rsp; dest] in
    [sub_rsp_ins; mov_ins]
  | Load (ty, op) ->
    (* Load the value from the address in op into the destination *)
    let dest = lookup uid ctxt.layout in
    let op_ins = compile_operand ctxt (Reg Rbx) op in
    let load_ins = X86.Movq, [Ind2 Rbx; Reg Rax] in
    let mov_ins = X86.Movq, [Reg Rax; dest] in
    [op_ins; load_ins; mov_ins]
  | Store (ty, op1, op2) -> 
    (* Store the value in op1 to the address in op2 *)
    let op1_ins = compile_operand ctxt (Reg Rbx) op1 in
    let op2_ins = compile_operand ctxt (Reg Rax) op2 in
    let store_ins = X86.Movq, [Reg Rbx; Ind2 Rax] in
    [op1_ins; op2_ins; store_ins]
  | Icmp (cnd, ty, op1, op2) -> 
    (* Set dest to 1 if cnd holds and 0 otherwise *)
    let dest = lookup uid ctxt.layout in
    let op1_ins = compile_operand ctxt (Reg Rbx) op1 in
    let op2_ins = compile_operand ctxt (Reg Rax) op2 in
    let cmp_ins = X86.Cmpq, [Reg Rax; Reg Rbx] in
    let set_ins = X86.Set (compile_cnd cnd), [Reg Rax] in
    let mov_ins = X86.Movq, [Reg Rax; dest] in
    [op1_ins; op2_ins; cmp_ins; set_ins; mov_ins]
  | Call (ty, op, args) -> 
    let dest = lookup uid ctxt.layout in
    compile_call ctxt (Some dest) op args
  | Bitcast (ty1, op, ty2) -> 
    let dest = lookup uid ctxt.layout in
    let op_ins = compile_operand ctxt (Reg Rax) op in
    let mov_ins = X86.Movq, [Reg Rax; dest] in
    [op_ins; mov_ins]
  | Gep (ty, op, path) -> 
    let dest = lookup uid ctxt.layout in
    let gep_insns = compile_gep ctxt (ty, op) path in
    let mov_ins = X86.Movq, [Reg Rax; dest] in
    gep_insns @ [mov_ins]



(* compiling terminators  --------------------------------------------------- *)

(* prefix the function name [fn] to a label to ensure that the X86 labels are
   globally unique . *)
let mk_lbl (fn:string) (l:string) = fn ^ "." ^ l

(* Compile block terminators is not too difficult:

   - Ret should properly exit the function: freeing stack space,
     restoring the value of %rbp, and putting the return value (if
     any) in %rax.

   - Br should jump

   - Cbr branch should treat its operand as a boolean conditional

   [fn] - the name of the function containing this terminator
*)
let compile_terminator (fn:string) (ctxt:ctxt) (t:Ll.terminator) (stack_cleanup: ins list) : ins list =
  if debug then Printf.printf "Compiling terminator %s\n" (Llutil.string_of_terminator t);
  match t with
  | Ret (ty, op) ->
      (* Move the return value into Rax *)
      let ret_ins = match op with
                    | Some o -> compile_operand ctxt (Reg Rax) o
                    | None -> X86.Movq, [Imm (Lit 0L); Reg Rax]
      in
      ret_ins :: (stack_cleanup) @ [X86.Retq , []] (* Return from the function *)
  (* Jump to the label address*)
  | Br lbl -> stack_cleanup @ [X86.Jmp, [Imm (Lbl (mk_lbl fn lbl))]]
  | Cbr (cond, ltrue, lfalse) -> 
      (* Compile the condition and compare it to 1 *)
      let cond_ins = compile_operand ctxt (Reg Rax) cond in
      let cmp_ins = X86.Cmpq, [Imm (Lit 1L); Reg Rax] in
      (* Jump to the true label if the condition is true, otherwise jump to the false label *)
      let jmp_ins = (X86.J X86.Eq, [Imm (Lbl (mk_lbl fn ltrue))]) :: [X86.J X86.Neq, [Imm (Lbl (mk_lbl fn lfalse))]] in
      (* Print jmp_ins if debug*)
      if debug then Printf.printf "Jmp Ins: %s\n" (String.concat ", " (List.map (fun (op, ops) -> X86.string_of_ins (op, ops)) jmp_ins));
      cond_ins :: cmp_ins :: (stack_cleanup) @ jmp_ins


(* compiling blocks --------------------------------------------------------- *)

(* We have left this helper function here for you to complete. 
   [fn] - the name of the function containing this block
   [ctxt] - the current context
   [blk]  - LLVM IR code for the block
*)
let compile_block (fn:string) (ctxt:ctxt) (blk:Ll.block) : ins list =
   if debug then Printf.printf "Compiling block %s\n" (Llutil.string_of_block blk);
  (* Check the rbp offset of the last element in ctxt.layout *)
  let stack_offset = match ctxt.layout with
    | (_, Ind3 (Lit n, Rbp)) :: _ -> if (Int64.to_int n > 0) then 0L else (Int64.neg n) (*If n > 0 then it is an argument and not a local id*)
    | _ -> 0L
  in
  (* push current rbp, set rbp to rsp *)
   let stack_setup = [
    Pushq, [Reg Rbp];           (* Save caller's base pointer *)
    Movq, [Reg Rsp; Reg Rbp];    (* Set rbp to rsp *)
    Subq, [Imm (Lit (stack_offset)); Reg Rsp] (* Allocate stack space for local variables *)
  ] in

  (* reset rsp to rbp, restore caller's rbp *)
  let stack_cleanup = [
    Movq, [Reg Rbp; Reg Rsp];   (* Reset rsp to current frame pointer *)
    Popq, [Reg Rbp]             (* Restore caller's base pointer *)
  ] in

  (* Compile each instruction in the block *)
  let insns = List.concat_map (compile_insn ctxt) blk.insns in
  (* Compile the terminator *)
  let term = (snd blk.term) in
  let terminator_ins = compile_terminator fn ctxt term stack_cleanup in
  stack_setup @ insns @ terminator_ins



let compile_lbl_block fn lbl ctxt blk : elem =
  Asm.gtext (mk_lbl fn lbl) (compile_block fn ctxt blk)



(* compile_fdecl ------------------------------------------------------------ *)


(* This helper function computes the location of the nth incoming
   function argument: either in a register or relative to %rbp,
   according to the calling conventions.  You might find it useful for
   compile_fdecl.

   [ NOTE: the first six arguments are numbered 0 .. 5 ]
*)
let arg_loc (n : int) : operand =
  match n with
  | 0 -> Reg Rdi
  | 1 -> Reg Rsi
  | 2 -> Reg Rdx
  | 3 -> Reg Rcx
  | 4 -> Reg R08
  | 5 -> Reg R09
  | _ -> Ind3 (Lit (Int64.of_int (16 + 8 * (n-6))), Rbp)  (* arguments are at positive offsets from %rbp *)


(* We suggest that you create a helper function that computes the
   stack layout for a given function declaration.

   - each function argument should be copied into a stack slot
   - in this (inefficient) compilation strategy, each local id
     is also stored as a stack slot.
   - see the discussion about locals

*)
let stack_layout (args : uid list) ((block, lbled_blocks):cfg) : layout =

  (* Compute the layout for the arguments and return max_i *)
  let arg_layout, max_i = List.fold_left (fun (acc, i) uid -> ((uid, arg_loc i) :: acc, i + 1)) ([], 0) args in
  let num_args = List.length args in
  let num_stack_args = if num_args > 6 then (num_args-6) else 0 in
  (* Store all the local ids in stack slots *)
  let block_insns = block.insns @ (List.concat_map (fun (_, b) -> b.insns) lbled_blocks) in
  let local_layout = List.fold_left (fun acc (uid, _) -> ((uid, Ind3 (Lit(Int64.of_int(-8 * (List.length acc + 1 + num_stack_args))), Rbp)) :: acc)) [] block_insns in
  local_layout @ arg_layout





(* The code for the entry-point of a function must do several things:

   - since our simple compiler maps local %uids to stack slots,
     compiling the control-flow-graph body of an fdecl requires us to
     compute the layout (see the discussion of locals and layout)

   - the function code should also comply with the calling
     conventions, typically by moving arguments out of the parameter
     registers (or stack slots) into local storage space.  For our
     simple compilation strategy, that local storage space should be
     in the stack. (So the function parameters can also be accounted
     for in the layout.)

   - the function entry code should allocate the stack storage needed
     to hold all of the local stack slots.
*)
let compile_fdecl (tdecls:(tid * ty) list) (name:string) ({ f_ty; f_param; f_cfg }:fdecl) : X86.prog =
  if debug then Printf.printf "--------------------------------\nCompiling function %s\n\n" name;
  let (main_block, additonal_blocks) = f_cfg in
  (* Compute Stacklayout for args and block *)
  let layout = stack_layout f_param f_cfg in
  if debug then Printf.printf "Tdecls: (%s)\n" (String.concat ", " (List.map (fun (tid, ty) -> (tid) ^ " -> " ^ (Llutil.string_of_ty ty)) tdecls));
  if debug then Printf.printf "Layout: (%s)\n" (String.concat ", " (List.map (fun (uid, op) -> (uid) ^ " -> " ^ (X86.string_of_operand op)) layout));
  (* Compile block context *)
  let ctxt = { tdecls; layout = layout } in

  (* Compile the main block *)
  let main_asm = compile_block name ctxt main_block in
  let main = { lbl = name; global = true; asm = Text main_asm } in
  
  (* Compile the blocks *)
  let blocks = List.map (fun (lbl, blk) -> compile_lbl_block name lbl ctxt blk) additonal_blocks in
  (main :: blocks)




(* compile_gdecl ------------------------------------------------------------ *)
(* Compile a global value into an X86 global data declaration and map
   a global uid to its associated X86 label.
*)
let rec compile_ginit : ginit -> X86.data list = function
  | GNull     -> [Quad (Lit 0L)]
  | GGid gid  -> [Quad (Lbl (Platform.mangle gid))]
  | GInt c    -> [Quad (Lit c)]
  | GString s -> [Asciz s]
  | GArray gs | GStruct gs -> List.map compile_gdecl gs |> List.flatten
  | GBitcast (t1,g,t2) -> compile_ginit g

and compile_gdecl (_, g) = compile_ginit g


(* compile_prog ------------------------------------------------------------- *)
let compile_prog {tdecls; gdecls; fdecls} : X86.prog =
  let g = fun (lbl, gdecl) -> Asm.data (Platform.mangle lbl) (compile_gdecl gdecl) in
  let f = fun (name, fdecl) -> compile_fdecl tdecls name fdecl in
  (List.map g gdecls) @ (List.map f fdecls |> List.flatten)
