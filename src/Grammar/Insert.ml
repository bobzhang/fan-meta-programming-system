


open Structure;
open Format;

let is_before s1 s2 = match (s1, s2) with
  [ (`Skeyword _ | `Stoken _, `Skeyword _ | `Stoken _) -> false
  | (`Skeyword _ | `Stoken _, _) -> true
  | _ -> false ];

let rec derive_eps = fun
  [ `Slist0 _ | `Slist0sep (_, _) | `Sopt _ -> true
  | `Stry s -> derive_eps s
  | `Stree t -> tree_derive_eps t
  | `Slist1 _ | `Slist1sep (_, _) | `Stoken _ | `Skeyword _ ->
      (* For sure we cannot derive epsilon from these *)
      false
  | `Smeta (_, _, _) | `Snterm _ | `Snterml (_, _) | `Snext | `Sself ->
        (* Approximation *)
      false ]
and tree_derive_eps = fun
    [ LocAct _ _ -> true
    | Node {node = s; brother = bro; son = son} ->
        derive_eps s && tree_derive_eps son || tree_derive_eps bro
    | DeadEnd -> false ];

(* create an empty level *)
let empty_lev lname assoc =
  let assoc = match assoc with
    [ Some a -> a
    | None -> `LA ] in
  {assoc ; lname ; lsuffix = DeadEnd; lprefix = DeadEnd};

let change_lev entry lev n lname assoc =
  let a = match assoc with
      [ None -> lev.assoc
      | Some a -> begin 
          if a <> lev.assoc && !(entry.egram.warning_verbose) then
            eprintf "<W> Changing associativity of level %S @." n
          else ();
          a
      end ] in begin 
      match lname with
      [ Some n ->
          if lname <> lev.lname && !(entry.egram.warning_verbose) then 
            eprintf "<W> Level label %S ignored@." n
          else ()
      | None -> () ];
        { (lev) with assoc=a}
    end ;
  
let change_to_self entry = fun
  [ `Snterm e when e == entry -> `Sself
  | x -> x ];

(* given [entry] [position] and [levs]  return [levs* (label name * assoc ) -> level  *levs]*)
let get_level entry position levs =
  match position with
  [ Some `First -> ([], empty_lev, levs)
  | Some `Last -> (levs, empty_lev, [])
  | Some (`Level n) ->
      let rec get = fun
        [ [] -> begin 
          eprintf "No level labelled %S in entry %S @." n entry.ename;
          failwith "Grammar.extend"
        end
        | [lev :: levs] ->
            if Tools.is_level_labelled n lev then
              ([], change_lev entry lev n, levs)
            else
              let (levs1, rlev, levs2) = get levs in
              ([lev :: levs1], rlev, levs2) ] in
      get levs
    | Some (`Before n) ->
        let rec get = fun
          [ [] -> begin
            eprintf "No level labelled %S in entry %S @." n entry.ename;
            failwith "Grammar.extend"
          end
          | [lev :: levs] ->
              if Tools.is_level_labelled n lev then ([], empty_lev, [lev :: levs])
              else
                let (levs1, rlev, levs2) = get levs in
                ([lev :: levs1], rlev, levs2) ] in
        get levs
    | Some (`After n) ->
        let rec get =  fun
          [ [] -> begin 
            eprintf "No level labelled %S in entry %S@." n entry.ename;
            failwith "Grammar.extend"
          end
          | [lev :: levs] ->
              if Tools.is_level_labelled n lev then
                ([lev], empty_lev, levs)
              else
                let (levs1, rlev, levs2) = get levs in
                ([lev :: levs1], rlev, levs2) ] in
        get levs
    | None ->  match levs with
        [ [lev :: levs] -> ([], change_lev entry lev "<top>", levs)
        | [] -> ([], empty_lev, []) ] ];

let rec check_gram entry = fun
  [ `Snterm e ->
    if e.egram != entry.egram then begin 
      eprintf "Error: entries %S and %S do not belong to the same grammar.@." entry.ename e.ename;
      failwith "Grammar.extend error"
    end
    else ()
  | `Snterml e _ ->
      if e.egram != entry.egram then begin
        eprintf "Error: entries %S and %S do not belong to the same grammar.@." entry.ename e.ename;
        failwith "Grammar.extend error"
      end
      else ()
  | `Smeta (_, sl, _) -> List.iter (check_gram entry) sl
  | `Slist0sep (s, t) -> begin check_gram entry t; check_gram entry s end
  | `Slist1sep (s, t) -> begin check_gram entry t; check_gram entry s end
  | `Slist0 s | `Slist1 s | `Sopt s | `Stry s -> check_gram entry s
  | `Stree t -> tree_check_gram entry t
  | `Snext | `Sself | `Stoken _ | `Skeyword _ -> () ]
and tree_check_gram entry = fun
  [ Node {node ; brother; son } -> begin 
    check_gram entry node;
    tree_check_gram entry brother;
    tree_check_gram entry son
  end
  | LocAct  _ | DeadEnd -> () ];

let get_initial = fun
    [ [`Sself :: symbols] -> (true, symbols)
    | symbols -> (false, symbols) ];

(* insert the symbol list into the gram, it will create side effect which will
   update the keyword table in the gram
 *)
let insert_tokens gram symbols =
  let rec insert = fun
    [ `Smeta _ sl _ -> List.iter insert sl
    | `Slist0 s | `Slist1 s | `Sopt s | `Stry s -> insert s
    | `Slist0sep (s, t) -> do { insert s; insert t }
    | `Slist1sep (s, t) -> do { insert s; insert t }
    | `Stree t -> tinsert t
    | `Skeyword kwd -> using gram kwd (* main meat *)
    | `Snterm _ | `Snterml (_, _) | `Snext | `Sself | `Stoken _ -> () ]
  and tinsert = fun
    [ Node {node = s; brother = bro; son = son} ->
      begin insert s; tinsert bro; tinsert son end
    | LocAct _ _ | DeadEnd -> () ] in
  List.iter insert symbols ;

(* given an [entry] [symbols] and [action] a tree, return a new [tree]*)
let insert_tree entry gsymbols action tree =
  let rec insert symbols tree =
    match symbols with
    [ [s :: sl] -> insert_in_tree s sl tree (* delegated to [insert_in_tree] *)
    | [] -> match tree with
        [ Node ({ brother;_} as x) ->  Node {(x) with brother = insert [] brother }
        | LocAct old_action action_list ->
            let () =
              if !(entry.egram.warning_verbose) then
                eprintf "<W> Grammar extension: in [%s] some rule has been masked@." entry.ename
              else ()in
            LocAct action [old_action :: action_list]
        | DeadEnd -> LocAct action [] ] ]
  and insert_in_tree s sl tree =
    match try_insert s sl tree with
    [ Some t -> t
    | None -> Node {node = s; son = insert sl DeadEnd; brother = tree} ]
  and try_insert s sl tree =
    match tree with
    [ Node ( {node ; son ; brother} as x) ->
      if Tools.eq_symbol s node then
        Some (Node { (x) with son = insert sl son})
      else if is_before node s || derive_eps s && not (derive_eps node) then
        let bro =
          match try_insert s sl brother with
          [ Some y -> y
          | None -> Node { (x) with node = s; son=insert sl DeadEnd } ] in
        Some (Node {(x) with brother=bro})
      else
        match try_insert s sl brother with
        [ Some y -> Some (Node {(x) with brother=y})
        | None -> None ]
    | LocAct _ _ | DeadEnd -> None ]  in
  insert gsymbols tree ;
  
let insert_level entry e1 symbols action slev =
  if e1 then
    {(slev) with lsuffix = insert_tree entry symbols action slev.lsuffix}
  else
    {(slev) with lprefix = insert_tree entry symbols action slev.lprefix};

(* given an [entry] [position] and [rules] return a new list of [levels]*)  
let levels_of_rules entry position rules =
  let elev = match entry.edesc with
    [ Dlevels elev -> elev
    | Dparser _ -> begin
        eprintf "Error: entry not extensible: %S@." entry.ename;
        failwith "Grammar.extend"
    end ] in
  if rules = [] then
    elev
  else
    let (levs1, make_lev, levs2) = get_level entry position elev in
    let (levs, _) =
      List.fold_left
        (fun (levs, make_lev) (lname, assoc, rules) ->
          let lev = make_lev lname assoc in
          let lev =
            List.fold_left
              (fun lev (symbols, action) ->
                let symbols = List.map (change_to_self entry) symbols in 
                  let () = List.iter (check_gram entry) symbols in 
                  let (e1, symbols) = get_initial symbols in 
                  let () =   insert_tokens entry.egram symbols in 
                  insert_level entry e1 symbols action lev) lev rules in
          ([lev :: levs], empty_lev)) ([], make_lev) rules in
      levs1 @ List.rev levs @ levs2 ;

(* mutate the [estart] and [econtinue] *)    
let extend entry (position, rules) =
  let elev = levels_of_rules entry position rules in begin 
    entry.edesc <- Dlevels elev;
    entry.estart <-
    fun lev strm ->
      let f = Parser.start_parser_of_entry entry in
      begin entry.estart <- f; f lev strm end;
    entry.econtinue <-
      fun lev bp a strm ->
        let f = Parser.continue_parser_of_entry entry in
        begin entry.econtinue <- f; f lev bp a strm end
  end;


