open Transform

open FSig

let _loc = FanLoc.ghost

let gen_stru ?module_name  ?(arity= 1)  ?(default=
  (`App
     (_loc, (`Lid (_loc, "failwith")),
       (`Str (_loc, "arity >= 2 in other branches"))) : Ast.exp ))
   ?cons_transform  ~id:(id : basic_id_transform)  ?(names= [])  ~mk_tuple 
  ~mk_record  ~mk_variant  () =
  let left_type_variable = `Pre "mf_" in
  let right_type_variable = `Pre "mf_" in
  let left_type_id = id in
  let right_type_id =
    match module_name with
    | None  -> (id :>full_id_transform)
    | Some m ->
        `Last
          ((fun s  ->
              `Dot
                (_loc, (`Uid (_loc, m)),
                  (`Lid (_loc, (basic_transform id s)))))) in
  let default (_,number) =
    if number > 1
    then
      let pat = EP.tuple_of_number (`Any _loc : Ast.pat ) arity in
      Some (`Case (_loc, pat, default) : Ast.case )
    else None in
  let names = names in
  let mk_record = mk_record in
  let cons_transform = cons_transform in
  let () = Frame.check names in
  let open Frame in
    stru_of_mtyps ?module_name ?cons_transform ~arity ~names ~default
      ~mk_variant ~left_type_id ~left_type_variable ~mk_record
      (normal_simple_exp_of_ctyp ~arity ~names ~mk_tuple ~right_type_id
         ~left_type_id ~right_type_variable)

let gen_object ?module_name  ?(arity= 1)  ?(default=
  (`App
     (_loc, (`Lid (_loc, "failwith")),
       (`Str (_loc, "arity >= 2 in other branches"))) : Ast.exp ))
   ?cons_transform  ~kind  ~base  ~class_name  =
  let make ?(names= [])  ~mk_tuple  ~mk_record  ~mk_variant  () =
    let () = Frame.check names in
    let left_type_variable = `Pre "mf_" in
    let right_type_variable =
      `Exp
        (fun v  ->
           let v = basic_transform left_type_variable v in
           (`App (_loc, (`Lid (_loc, v)), (`Lid (_loc, "self"))) : Ast.exp )) in
    let left_type_id = `Pre "" in
    let right_type_id = `Obj (basic_transform left_type_id) in
    let default (_,number) =
      if number > 1
      then
        let pat = EP.tuple_of_number (`Any _loc : Ast.pat ) arity in
        Some (`Case (_loc, pat, default) : Ast.case )
      else None in
    let open Frame in
      obj_of_mtyps ?cons_transform ?module_name ~arity ~names ~default
        ~left_type_variable ~mk_record ~mk_variant base class_name
        (obj_simple_exp_of_ctyp ~right_type_id ~left_type_variable
           ~right_type_variable ~names ~arity ~mk_tuple) kind in
  make