

open Util
open Astn_util
open Astfn
open Ctyp

let check _ = ()
type param =
    {arity: int;
     names: string list;
   }
let normal_simple_exp_of_ctyp
    ?arity ?names ~mk_tuple
    ~left_type_id
    (ty:ctyp) = 
  let right_trans = left_transform left_type_id  in
  let tyvar = Ctyp.right_transform (`Pre "mf_")  in
  let rec aux  x : exp =
    match x with 
    | `Lid id -> (right_trans id :> exp )
    | (#ident' as id) ->
        (Idn_util.ident_map_of_ident right_trans (Idn_util.to_vid id ) :> exp)
    | `App(t1,t2) ->
        %exp-{ ${aux t1} ${aux t2} }
    | `Quote (_,`Lid s) ->   tyvar s
    | `Arrow(t1,t2) ->
        aux %ctyp-{ ($t1,$t2) arrow } (* arrow is a keyword now*)
    | `Par _  as ty ->
        tuple_exp_of_ctyp  ?arity ?names ~mk_tuple
          ~f:aux ty 
    | (ty:ctyp) -> (* TOPBIND required *)
       failwithf "normal_simple_exp_of_ctyp : %s"
          (Astfn_print.dump_ctyp ty) in
  aux ty
let mk_prefix ?(names=[]) (vars:opt_decl_params) (acc:exp)   = 
  let varf = basic_transform (`Pre "mf_") in
  let  f (var:decl_params) acc =
    match var with
    | `Quote(_,`Lid(s)) -> %exp-{ fun $lid{ varf s} -> $acc }
    | t  ->
        failwithf  "mk_prefix: %s" (Astfn_print.dump_decl_params t) in
  match vars with
  |`None  -> Expn_util.abstract names  acc
  |`Some xs ->
      let vars = Ast_basic.N.list_of_com xs [] in
      List.fold_right f vars (Expn_util.abstract names  acc)

        
let exp_of_ctyp
    (* ?cons_transform *)
    ?(arity=1)
    ?(names=[])
    ~default ~mk_variant
    simple_exp_of_ctyp (ty : or_ctyp)  =
  let f  (cons:string) (tyargs:ctyp list )  : case =
    let args_length = List.length tyargs in  (* ` is not needed here *)
    let p : pat =
      (* calling gen_tuple_n*)
      (Id_epn.gen_tuple_n (* ?cons_transform *) ~arity  cons args_length :> pat) in
    let mk (cons,tyargs) =
      let exps = List.mapi (mapi_exp ~arity ~names ~f:simple_exp_of_ctyp) tyargs in
      mk_variant (Some cons) exps in
    let e = mk (cons,tyargs) in
    %case-{ $pat:p -> $e } in  begin
    let info = (Sum, List.length (Ast_basic.N.list_of_bar ty [])) in
    let res :  case list =
      Ctyp.reduce_data_ctors ty  [] f ~compose:cons  in
    let res =
      let t = (* only under this case we need defaulting  *)
        if List.length res >= 2 && arity >= 2 then
          match default info with
          | Some x-> x::res
          | None -> res
        else res in
      List.rev t in
    Expn_util.currying ~arity res
  end

        
let exp_of_variant (* ?cons_transform *)
    ?(arity=1)?(names=[]) ~default ~mk_variant ~destination
    simple_exp_of_ctyp ~result ty =
  let f (cons,tyargs) :  case=
    let len = List.length tyargs in
    let p = (Id_epn.gen_tuple_n (* ?cons_transform *) ~arity cons len :> pat) in
    let mk (cons,tyargs) =
      let exps = List.mapi (mapi_exp ~arity ~names ~f:simple_exp_of_ctyp) tyargs in
      mk_variant (Some cons) exps in
    let e = mk (cons,tyargs) in
    %case-{ $pat:p -> $e } in 
  (* for the case [`a | b ] *)
  let simple (lid:ident) :case=
    let e = (simple_exp_of_ctyp (lid:>ctyp)) +> names  in
    let (f,a) = Ast_basic.N.view_app [] result in
    let annot = appl_of_list (f :: List.map (fun _ -> `Any) a) in
    gen_tuple_abbrev ~arity ~annot ~destination lid e in
  (* FIXME, be more precise  *)
  let info = (TyVrnEq, List.length (Ast_basic.N.list_of_bar ty [])) in
  let ls = Ctyp.view_variant ty in
  let res =
    let res = List.fold_left
      (fun  acc x ->
        match x with
        | `variant (cons,args) -> f ("`"^cons,args)::acc
        | `abbrev lid ->  simple lid :: acc  )  [] ls in
  let t =
    if List.length res >= 2 && arity >= 2 then
      match default info with | Some x-> x::res | None -> res 
      (* [default info :: res] *)
    else res in
  List.rev t in
  Expn_util.currying ~arity res

        
(*
  Given type declarations, generate corresponding
  Astf node represent the [function]
  (combine both exp_of_ctyp and simple_exp_of_ctyp) *)  
let fun_of_tydcl
    ?(names=[]) ?(arity=1)  ~mk_record  ~result
    simple_exp_of_ctyp exp_of_ctyp exp_of_variant  tydcl :exp = 
    match (tydcl:decl) with 
    | `TyDcl ( _, tyvars, ctyp, _constraints) ->
       begin match ctyp with
       |  `TyMan(_,_,repr) | `TyRepr(_,repr) ->
         begin match repr with
         | `Record t ->       
           let cols =  Ctyp.list_of_record t  in
           let pat = (Ctyp.mk_record ~arity  cols  :> pat)in
           let info =
             List.mapi
               (fun i x ->
                 match (x:Ctyp.col) with
                   {label;is_mutable;ty} ->
                     {info = (mapi_exp ~arity ~names ~f:simple_exp_of_ctyp) i ty  ;
                      label;
                      is_mutable}) cols in
        (* For single tuple pattern match this can be optimized
           by the ocaml compiler *)
        mk_prefix ~names  tyvars
            (Expn_util.currying ~arity [ %case-{ $pat:pat -> ${mk_record info}  } ])

       |  `Sum ctyp -> 
          let funct = exp_of_ctyp ctyp in  
          (* for [exp_of_ctyp] appending names was delayed to be handled in mkcon *)
          mk_prefix ~names  tyvars funct
       | t ->
          failwithf "fun_of_tydcl outer %s" (Astfn_print.dump_type_repr t)
         end
    | `TyEq(_,ctyp) ->
        begin match ctyp with 
        | (#ident'  | `Par _ | `Quote _ | `Arrow _ | `App _ as x) ->
          let exp = simple_exp_of_ctyp x in
          let funct = Expn_util.eta_expand (exp+>names) arity  in
          mk_prefix ~names  tyvars funct
        | `PolyEq t | `PolySup t | `PolyInf t|`PolyInfSup(t,_) -> 
            let case =  exp_of_variant ~result t  in
            mk_prefix ~names  tyvars case
        | t -> failwithf "fun_of_tydcl inner %s" (Astfn_print.dump_ctyp t)
        end
    | t -> failwithf  "fun_of_tydcl middle %s" (Astfn_print.dump_type_info t)
       end
   | t -> failwithf "fun_of_tydcl outer %s" (Astfn_print.dump_decl t)

let bind_of_tydcl (* ?cons_transform *) simple_exp_of_ctyp
    ?(arity=1) ?(names=[])
    ?(destination=Str_item)
    ?annot
    ~default ~mk_variant
    ~left_type_id
    ~mk_record
    tydcl
    = 
  let tctor_var = left_transform left_type_id in
  let (name,len) =
    match  tydcl with
    | `TyDcl ( `Lid name, tyvars, _, _) ->
        (name, match tyvars with
        | `None  -> 0
        | `Some xs -> List.length @@ Ast_basic.N.list_of_com  xs [])
    | tydcl ->
        failwith (__BIND__ ^ Astfn_print.dump_decl tydcl) in
  let fname = tctor_var name in
  let prefix = List.length names in
  (* FIXME the annot using [_ty]?*)
  let (_ty,result) =
    Ctyp.mk_method_type
      ~number:arity ~prefix
      ~id:(lid name)
      len destination in (* FIXME *)
  let (annot,result) =
    match annot with
    |None -> (None,result)
    |Some (f:string -> (ctyp * ctyp))  -> let (a,b) = f name in (Some a, b) in 

  let fun_exp =
    if not @@  Ctyp.is_abstract tydcl then 
      fun_of_tydcl 
        ~names ~arity  ~mk_record
        ~result
        simple_exp_of_ctyp
        (exp_of_ctyp  ~arity ~names ~default ~mk_variant simple_exp_of_ctyp)
        (exp_of_variant
           ~arity ~names ~default ~mk_variant
           ~destination simple_exp_of_ctyp)
        tydcl
    else
      begin 
        Format.eprintf "Warning: %s as a abstract type no structure generated\n" @@ Astfn_print.dump_decl tydcl;
        %exp-{ failwith "Abstract data type not implemented" }
      end in
  match annot with
  | None -> 
      %bind-{ $fname = $fun_exp }
  | Some x ->
      %bind-{ $fname  = ($fun_exp : $x ) }
        

let stru_of_mtyps  (* ?cons_transform *) ?annot
    ?arity ?names ~default ~mk_variant ~left_type_id 
    ~mk_record
    simple_exp_of_ctyp_with_cxt
    (lst:Sigs_util.mtyps) : stru =
  let mk_bind : decl -> bind =
    bind_of_tydcl (* ?cons_transform *) ?arity ?annot
      ?names ~default ~mk_variant ~left_type_id  ~mk_record
      (simple_exp_of_ctyp_with_cxt (* cxt *)) in
  (* return new types as generated  new context *)
  let fs (ty:Sigs_util.types) : stru=
    match ty with
    | `Mutual named_types ->
        begin match named_types with
        | [] ->  %stru-{ let _ = ()} (* FIXME *)
        | xs ->
            
            let bind =
              Listf.reduce_right_with
                ~compose:(fun x y -> %bind-{ $x and $y } )
                ~f:(fun (_name,ty) ->
                  mk_bind  ty ) xs in
            %stru-{ let rec $bind }
        end
    | `Single (_,tydcl) ->
         let flag =
           if Ctyp.is_recursive tydcl then `Positive 
           else `Negative  
         and bind = mk_bind  tydcl in 
         %stru-{ let $rec:flag  $bind } in
    match lst with
    | [] -> %stru-{let _ = ()}
    | _ ->  sem_of_list (List.map fs lst )

            

(*************************************************************************)
(**
  Generate warnings for abstract data type
  and qualified data type.
  all the types in one module will derive a class  *)
(*************************************************************************)

(** For var, in most cases we just add a prefix
   mf_, so we just fix it here

   For Objects, tctor_var, always (`Fun (fun x -> x))
   FIXME we may need a more flexible way to compose branches
 *)
let mk
    ?(arity=1)
    ?(default= %exp-{ failwith "arity >= 2 in other branches" } )
    (* ?cons_transform *)
    ?annot
    ~id:(id:basic_id_transform)  ?(names=[])  
    (* you must specify when arity >=2 *)
    ~mk_record:(mk_record:(record_col list -> exp)) ~mk_variant ()= 
  let left_type_id = id in
  let default (_,number)=
    if number > 1 then
      let pat = (Id_epn.tuple_of_number `Any  arity :> pat) in 
      Some %case-{ $pat:pat -> $default }
    else None in
  let names = names in
  let mk_record = mk_record in
  (* let cons_transform = cons_transform in *)
  let () = check names in
  let mk_tuple = mk_variant None in
  stru_of_mtyps
    (* ?cons_transform *)
    ?annot
    ~arity
    ~names
    ~default
    ~mk_variant
    ~left_type_id
    ~mk_record
    (normal_simple_exp_of_ctyp
       ~arity ~names ~mk_tuple
       ~left_type_id )
    

(* local variables: *)
(* compile-command: "cd .. && pmake main_annot/derive_stru.cmo" *)
(* end: *)
