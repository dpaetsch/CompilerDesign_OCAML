(** Alias Analysis *)

open Ll
open Datastructures

(* The lattice of abstract pointers ----------------------------------------- *)
module SymPtr =
  struct
    type t = MayAlias           (* uid names a pointer that may be aliased *)
           | Unique             (* uid is the unique name for a pointer *)
           | UndefAlias         (* uid is not in scope or not a pointer *)

    let compare : t -> t -> int = Pervasives.compare

    let to_string = function
      | MayAlias -> "MayAlias"
      | Unique -> "Unique"
      | UndefAlias -> "UndefAlias"

    (* helper function for join two SymPtr.t facts. *)
    let join fact1 fact2 = match fact1, fact2 with
      | MayAlias , _ | _ , MayAlias -> MayAlias
      | Unique , Unique -> Unique
      | UndefAlias , x | x , UndefAlias -> x

  end

(* The analysis computes, at each program point, which UIDs in scope are a unique name
   for a stack slot and which may have aliases *)
type fact = SymPtr.t UidM.t

(* flow function across Ll instructions ------------------------------------- *)
(* TASK: complete the flow function for alias analysis. 

   - After an alloca, the defined UID is the unique name for a stack slot
   - A pointer returned by a load, call, bitcast, or GEP may be aliased
   - A pointer passed as an argument to a call, bitcast, GEP, or store
     may be aliased
   - Other instructions do not define pointers

 *)
 let insn_flow ((u, i): uid * insn) (d: fact) : fact =
  (* failwith "Alias.insn_flow not implemented" *)
  (* Added: *)
  let add_alias key sym d = UidM.add key sym d in
  let matches_ptr_type = function
    | Ptr _ -> true
    | _ -> false
  in
  match i with
  | Alloca _ -> add_alias u SymPtr.Unique d
  | Load (Ptr (Ptr _), _) -> add_alias u SymPtr.MayAlias d
  | Store (Ptr _, Id v, _) -> add_alias v SymPtr.MayAlias d
  | Call (ty, _, args) ->
      let d = (if matches_ptr_type ty then add_alias u SymPtr.MayAlias d else d) in
      List.fold_left (fun acc (ty, op) ->
        match ty, op with
        | Ptr _, Id v -> add_alias v SymPtr.MayAlias acc
        | _ -> acc) d args
  | Bitcast (_, Id v, _) | Gep (_, Id v, _) ->
      d |> add_alias v SymPtr.MayAlias |> add_alias u SymPtr.MayAlias
  | Bitcast _ | Gep (_, _, _) -> add_alias u SymPtr.MayAlias d
  | _ -> d

  (* *)


(* The flow function across terminators is trivial: they never change alias info *)
let terminator_flow t (d:fact) : fact = d

(* module for instantiating the generic framework --------------------------- *)
module Fact =
  struct
    type t = fact
    let forwards = true

    let insn_flow = insn_flow
    let terminator_flow = terminator_flow
    
    (* UndefAlias is logically the same as not having a mapping in the fact. To
       compare dataflow facts, we first remove all of these *)
    let normalize : fact -> fact = 
      UidM.filter (fun _ v -> v != SymPtr.UndefAlias)

    let compare (d:fact) (e:fact) : int = 
      UidM.compare SymPtr.compare (normalize d) (normalize e)

    let to_string : fact -> string =
      UidM.to_string (fun _ v -> SymPtr.to_string v)

    (* TASK: complete the "combine" operation for alias analysis.

       The alias analysis should take the join over predecessors to compute the
       flow into a node. You may find the UidM.merge function useful.

       It may be useful to define a helper function that knows how to take the
       join of two SymPtr.t facts.
    *)
    let combine (ds:fact list) : fact =
      (* failwith "Alias.Fact.combine not implemented" *)
      (* Added: *)
      let combine_element make_map fact_list =
        UidM.merge
          (fun _ map fact ->
             match map, fact with
             | Some map_val, Some fact_val -> Some (SymPtr.join map_val fact_val)
             | Some map_val, None | None, Some map_val -> Some map_val
             | None, None -> None)
          make_map
          fact_list
      in
      List.fold_left (fun acc fact -> combine_element acc fact) UidM.empty ds
      (* *)
  end

(* instantiate the general framework ---------------------------------------- *)
module Graph = Cfg.AsGraph (Fact)
module Solver = Solver.Make (Fact) (Graph)

(* expose a top-level analysis operation ------------------------------------ *)
let analyze (g:Cfg.t) : Graph.t =
  (* the analysis starts with every node set to bottom (the map of every uid 
     in the function to UndefAlias *)
  let init l = UidM.empty in

  (* the flow into the entry node should indicate that any pointer parameter 
     to the function may be aliased *)
  let alias_in = 
    List.fold_right 
      (fun (u,t) -> match t with
                    | Ptr _ -> UidM.add u SymPtr.MayAlias
                    | _ -> fun m -> m) 
      g.Cfg.args UidM.empty 
  in
  let fg = Graph.of_cfg init alias_in g in
  Solver.solve fg
