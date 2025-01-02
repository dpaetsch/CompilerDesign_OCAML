open Ll
open Datastructures

(* The lattice of symbolic constants ---------------------------------------- *)
module SymConst =
  struct
    type t = NonConst           (* Uid may take on multiple values at runtime *)
           | Const of int64     (* Uid will always evaluate to const i64 or i1 *)
           | UndefConst         (* Uid is not defined at the point *)

    let compare s t =
      match (s, t) with
      | (Const i, Const j) -> Int64.compare i j
      | (NonConst, NonConst) | (UndefConst, UndefConst) -> 0
      | (NonConst, _) | (_, UndefConst) -> 1
      | (UndefConst, _) | (_, NonConst) -> -1

    let to_string : t -> string = function
      | NonConst -> "NonConst"
      | Const i -> Printf.sprintf "Const (%LdL)" i
      | UndefConst -> "UndefConst"

    (* Added: *)
    (* helper function for join two SymPtr.t facts. *)
    let join fact1 fact2 = match fact1, fact2 with
      | UndefConst, Const x -> Const x
      | Const x, UndefConst -> Const x
      | Const x, Const y -> if x = y then Const x else NonConst
      | NonConst , _ | _ , NonConst -> NonConst
      | _ -> UndefConst
    (* *)
    
  end

(* The analysis computes, at each program point, which UIDs in scope will evaluate 
   to integer constants *)
type fact = SymConst.t UidM.t



(* flow function across Ll instructions ------------------------------------- *)
(* - Uid of a binop or icmp with const arguments is constant-out
   - Uid of a binop or icmp with an UndefConst argument is UndefConst-out
   - Uid of a binop or icmp with an NonConst argument is NonConst-out
   - Uid of stores and void calls are UndefConst-out
   - Uid of all other instructions are NonConst-out
 *)

 (* Added *)

 let solve_binop (op: bop) (x: int64) (y: int64) : int64 =
  match op with
  | Add -> Int64.add x y
  | Sub -> Int64.sub x y
  | Mul -> Int64.mul x y
  | Shl -> Int64.shift_left x (Int64.to_int y)
  | Lshr -> Int64.shift_right_logical x (Int64.to_int y)
  | Ashr -> Int64.shift_right x (Int64.to_int y)
  | And -> Int64.logand x y
  | Or -> Int64.logor x y
  | Xor -> Int64.logxor x y

let solve_icmp (cnd: cnd) (x: int64) (y: int64) : int64 =
  let compare_result =
    match cnd with
    | Eq -> x = y
    | Ne -> x <> y
    | Slt -> x < y
    | Sle -> x <= y
    | Sgt -> x > y
    | Sge -> x >= y
  in
  if compare_result then 1L else 0L

let solve_op (op: operand) (d: fact) : SymConst.t =
  match op with
  | Null -> SymConst.UndefConst
  | Const x -> SymConst.Const x
  | Id id | Gid id -> (
      match UidM.find_opt id d with
      | None -> SymConst.UndefConst
      | Some value -> value)

let insn_flow ((u, i): uid * insn) (d: fact) : fact =
  let update_fact uid value fact = UidM.add uid value fact in
  match i with
  | Binop (op, _, op1, op2) -> (
      match solve_op op1 d, solve_op op2 d with
      | SymConst.Const x, SymConst.Const y ->
          update_fact u (SymConst.Const (solve_binop op x y)) d
      | SymConst.UndefConst, _ | _, SymConst.UndefConst ->
          update_fact u SymConst.UndefConst d
      | _ -> update_fact u SymConst.NonConst d)
  | Icmp (op, _, op1, op2) -> (
      match solve_op op1 d, solve_op op2 d with
      | SymConst.Const x, SymConst.Const y ->
          update_fact u (SymConst.Const (solve_icmp op x y)) d
      | SymConst.UndefConst, _ | _, SymConst.UndefConst ->
          update_fact u SymConst.UndefConst d
      | _ -> update_fact u SymConst.NonConst d)
  | Store (_, _, Id id) | Store (_, _, Gid id) ->
      update_fact u SymConst.UndefConst d
  | Call (Void, _, _) -> update_fact u SymConst.UndefConst d
  | _ -> update_fact u SymConst.NonConst d

(* *)

(* The flow function across terminators is trivial: they never change const info *)
let terminator_flow (t:terminator) (d:fact) : fact = d

(* module for instantiating the generic framework --------------------------- *)
module Fact =
struct
  type t = fact
  let forwards = true
  let insn_flow = insn_flow
  let terminator_flow = terminator_flow

  let normalize (f: fact) : fact =
    UidM.filter (fun _ v -> v != SymConst.UndefConst) f

  let compare (d: fact) (e: fact) : int =
    UidM.compare SymConst.compare (normalize d) (normalize e)

  let to_string (f: fact) : string =
    UidM.to_string (fun _ v -> SymConst.to_string v) f

  let combine (facts: fact list) : fact =
    let merge_facts acc fact =
      UidM.merge
        (fun _ v1 v2 -> match v1, v2 with
           | Some v1, Some v2 -> Some (SymConst.join v1 v2)
           | Some v, None | None, Some v -> Some v
           | None, None -> None)
        acc fact
    in
    List.fold_left merge_facts UidM.empty facts
end

(* instantiate the general framework ---------------------------------------- *)
module Graph = Cfg.AsGraph (Fact)
module Solver = Solver.Make (Fact) (Graph)

(* expose a top-level analysis operation ------------------------------------ *)
let analyze (g:Cfg.t) : Graph.t =
  (* the analysis starts with every node set to bottom (the map of every uid 
     in the function to UndefConst *)
  let init l = UidM.empty in

  (* the flow into the entry node should indicate that any parameter to the
     function is not a constant *)
  let cp_in = List.fold_right 
    (fun (u,_) -> UidM.add u SymConst.NonConst)
    g.Cfg.args UidM.empty 
  in
  let fg = Graph.of_cfg init cp_in g in
  Solver.solve fg


(* run constant propagation on a cfg given analysis results ----------------- *)
(* HINT: your cp_block implementation will probably rely on several helper 
   functions.                                                                 *)
let run (cg: Graph.t) (cfg: Cfg.t) : Cfg.t =
  let cp_block (l: Ll.lbl) (cfg: Cfg.t) : Cfg.t =
    
    let b = Cfg.block cfg l in
    let cb = Graph.uid_out cg l in

    let check_term (id, term) =
      let temp = cb id in
      let helper op =
        match op with
        | Gid id | Id id -> (match UidM.find id temp with Const x -> Const x | _ -> op)
        | _ -> op
      in
      match term with
      | Ret (ty, Some op) -> (id, Ret (ty, Some (helper op)))
      | Cbr (op, l1, l2) -> (id, Cbr (helper op, l1, l2))
      | _ -> (id, term)
    in

    let check_instr (id, ins) =
      let temp = cb id in
      let helper op =
        match op with
        | Gid id | Id id -> (match UidM.find_opt id temp with Some (Const x) -> Const x | _ -> op)
        | _ -> op
      in
      match ins with
      | Binop (bop, ty, op1, op2) -> (id, Binop (bop, ty, helper op1, helper op2))
      | Icmp (cnd, ty, op1, op2) -> (id, Icmp (cnd, ty, helper op1, helper op2))
      | Load (ty, op) -> (id, Load (ty, helper op))
      | Store (ty, op1, op2) -> (id, Store (ty, helper op1, helper op2))
      | Call (ty, op, op_list) -> (id, Call (ty, helper op, List.map (fun (x, y) -> (x, helper y)) op_list))
      | Bitcast (ty1, op, ty2) -> (id, Bitcast (ty1, helper op, ty2))
      | _ -> (id, ins)
    in

    let block = { insns = List.map check_instr b.insns; term = check_term b.term } in
    { cfg with blocks = LblM.add l block (LblM.remove l cfg.blocks) }
  in

  LblS.fold cp_block (Cfg.nodes cfg) cfg
