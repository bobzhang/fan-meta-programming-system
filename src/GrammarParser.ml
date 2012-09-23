open FanSig;
open FanUtil;
module MakeGrammarParser (Syntax : Camlp4.Sig.Camlp4Syntax) = struct
  open Camlp4.Sig;
  include Syntax;

  module MetaLoc = Ast.Meta.MetaGhostLoc;
  module MetaAst = Ast.Meta.Make MetaLoc;
  value string_of_patt patt =
    let buf = Buffer.create 42 in
    let () =
      Format.bprintf buf "%a@?"
        (fun fmt p -> Pprintast.pattern fmt (Syntax.Ast2pt.patt p)) patt in
    (* let () = Format.bprintf buf "%a@?" pp#patt patt in *)
    let str = Buffer.contents buf in
    if str = "" then assert False else str;

  value split_ext = ref False;

  type loc = Loc.t;

  type name 'e = { expr : 'e; tvar : string; loc : loc };

  type styp =
    [ STlid of loc and string
    | STapp of loc and styp and styp
    | STquo of loc and string
    | STself of loc and string
    | STtok of loc
    | STstring_tok of loc
    | STtyp of Ast.ctyp ]
  ;

  type text 'e 'p =
    [ TXmeta of loc and string and list (text 'e 'p) and 'e and styp
    | TXlist of loc and bool and symbol 'e 'p and option (symbol 'e 'p)
    | TXnext of loc
    | TXnterm of loc and name 'e and option string
    | TXopt of loc and text 'e 'p
    | TXtry of loc and text 'e 'p
    | TXrules of loc and list (list (text 'e 'p) * 'e)
    | TXself of loc
    | TXkwd of loc and string
    | TXtok of loc and 'e and string
         (** The first is the match function expr,
             the second is the string description.
             The description string will be used for
             grammar insertion and left factoring.
             Keep this string normalized and well comparable. *) ]
  and entry 'e 'p =
    { name : name 'e; pos : option 'e; levels : list (level 'e 'p) }
  and level 'e 'p =
    { label : option string; assoc : option 'e; rules : list (rule 'e 'p) }
  and rule 'e 'p = { prod : list (symbol 'e 'p); action : option 'e }
  and symbol 'e 'p = { used : list string; text : text 'e 'p;
                       styp : styp; pattern : option 'p }
  ;

  type used = [ Unused | UsedScanned | UsedNotScanned ];

  value _loc = Loc.ghost;
  value gm = "Camlp4Grammar__";

  value mark_used modif ht n =
    try
      let rll = Hashtbl.find_all ht n in
      List.iter
        (fun [ (({val=Unused} as r), _)   ->  begin 
            r.val := UsedNotScanned; modif.val := True;
          end
          |  _ -> () ])
        rll
    with
    [ Not_found -> () ]
  ;

  value rec mark_symbol modif ht symb =
    List.iter (fun e -> mark_used modif ht e) symb.used
  ;

  value check_use nl el =
    let ht = Hashtbl.create 301 in
    let modif = ref False in
    do {
      List.iter
        (fun e ->
          let u =
            match e.name.expr with
            [ <:expr< $lid:_ >> -> Unused
            | _ -> UsedNotScanned ]
          in
          Hashtbl.add ht e.name.tvar (ref u, e))
        el;
      List.iter
        (fun n ->
          try
            let rll = Hashtbl.find_all ht n.tvar in
            List.iter (fun (r, _) -> r.val := UsedNotScanned) rll
          with _ ->
            ())
        nl;
      modif.val := True;
      while modif.val do {
        modif.val := False;
        Hashtbl.iter
          (fun _ (r, e) ->
            if r.val = UsedNotScanned then do {
              r.val := UsedScanned;
              List.iter
                (fun level ->
                    let rules = level.rules in
                    List.iter
                      (fun rule ->
                        List.iter (fun s -> mark_symbol modif ht s)
                          rule.prod)
                      rules)
                e.levels
            }
            else ())
          ht
      };
      Hashtbl.iter
        (fun s (r, e) ->
          if r.val = Unused then
            print_warning e.name.loc ("Unused local entry \"" ^ s ^ "\"")
          else ())
        ht;
    }
  ;

  value new_type_var =
    let i = ref 0 in fun () -> do { incr i; "e__" ^ string_of_int i.val }
  ;

  value used_of_rule_list rl =
    List.fold_left
      (fun nl r -> List.fold_left (fun nl s -> s.used @ nl) nl r.prod) []
      rl
  ;

  value retype_rule_list_without_patterns _loc rl =
    try
      List.map
        (fun
          (* ...; [ "foo" ]; ... ==> ...; (x = [ "foo" ] -> Gram.Token.extract_string x); ... *)
        [ {prod = [({pattern = None; styp = STtok _} as s)]; action = None} ->
            {prod = [{ (s) with pattern = Some <:patt< x >> }];
              action = Some <:expr< $uid:gm.Token.extract_string x >>}
          (* ...; [ symb ]; ... ==> ...; (x = [ symb ] -> x); ... *)
        | {prod = [({pattern = None} as s)]; action = None} ->
            {prod = [{ (s) with pattern = Some <:patt< x >> }];
              action = Some <:expr< x >>}
          (* ...; ([] -> a); ... *)
        | {prod = []; action = Some _} as r -> r
        | _ -> raise Exit ])
        rl
    with
    [ Exit -> rl ]
  ;

  value meta_action = ref False;

  (*
    {[
    
    ]}
   *)  
  value mklistexp _loc =
    loop True where rec loop top =
      fun
      [ [] -> <:expr< [] >>
      | [e1 :: el] ->
          let _loc =
            if top then _loc else Loc.merge (Ast.loc_of_expr e1) _loc
          in
          <:expr< [$e1 :: $(loop False el)] >> ]
  ;

  (*
    {[
    
    ]}
   *)      
  value mklistpat _loc =
    loop True where rec loop top =
      fun
      [ [] -> <:patt< [] >>
      | [p1 :: pl] ->
          let _loc =
            if top then _loc else Loc.merge (Ast.loc_of_patt p1) _loc
          in
          <:patt< [$p1 :: $(loop False pl)] >> ]
  ;
  (*
    expand function application 
   *)
  value rec expr_fa al =
    fun
    [ <:expr< $f $a >> -> expr_fa [a :: al] f
    | f -> (f, al) ]
  ;

  value rec make_ctyp styp tvar =
    match styp with
    [ STlid _loc s -> <:ctyp< $lid:s >>
    | STapp _loc t1 t2 -> <:ctyp< $(make_ctyp t1 tvar) $(make_ctyp t2 tvar) >>
    | STquo _loc s -> <:ctyp< '$s >>
    | STself _loc x ->
        if tvar = "" then
          Loc.raise _loc
            (Stream.Error ("'" ^ x ^  "' illegal in anonymous entry level"))
        else <:ctyp< '$tvar >>
    | STtok _loc -> <:ctyp< $uid:gm.Token.t >>
    | STstring_tok _loc -> <:ctyp< string >>
    | STtyp t -> t ]
  ;

  (*
    {[
    styp generates type constraints which are used to constrain patt
    ]}
   *)    
  value make_ctyp_patt styp tvar patt =
    let styp = match styp with [ STstring_tok _loc -> STtok _loc | t -> t ] in
    match make_ctyp styp tvar with
    [ <:ctyp< _ >> -> patt (* FIXME *)
    | t -> let _loc = Ast.loc_of_patt patt in <:patt< ($patt : $t) >> ];

  value make_ctyp_expr styp tvar expr =
    match make_ctyp styp tvar with
    [ <:ctyp< _ >> -> expr
    | t -> let _loc = Ast.loc_of_expr expr in <:expr< ($expr : $t) >> ];

  (*
    {[
    ('j, Ast.patt) symbol list
    The API is used to generate [action]
    ]}
   *)    
  value text_of_action _loc (psl: list (symbol 'j Ast.patt)) (rtvar:string) (act:option Ast.expr) (tvar:string) =
    let locid = <:patt< $(lid: Loc.name.val) >> in (* default is [_loc]*)
    let act = match act with
      [ Some act -> act
      | None -> <:expr< () >> ] in
    let (tok_match_pl, act, _) =
      List.fold_left
        (fun ((tok_match_pl, act, i) as accu) ->
          fun
          [ { pattern = None; _ } -> accu
          | { pattern = Some p ; _} when Ast.is_irrefut_patt p -> accu
          | { pattern = Some <:patt< ($_ $(tup:<:patt< _ >>) as $lid:s) >> } ->
              (tok_match_pl,
               <:expr< let $lid:s = $uid:gm.Token.extract_string $lid:s
                       in $act >>, i)
          | { pattern = Some p; text=TXtok _ _ _ } ->
              let id = "__camlp4_"^string_of_int i in
              (Some (match (tok_match_pl) with
                     [ None -> (<:expr< $lid:id >>, p)
                     | Some (tok_pl, match_pl) ->
                        (<:expr< $lid:id, $tok_pl >>, <:patt< $p, $match_pl >>)]),
               act, succ i)
          | _ -> accu ])
        (None, act, 0) psl in
    let e =
      let e1 = <:expr< ($act : '$rtvar) >> in
      let e2 =
        match (tok_match_pl) with
        [ None -> e1
        | Some (<:expr< $t1, $t2 >>, <:patt< $p1, $p2 >>) ->
          <:expr< match ($t1, $t2) with
                  [ ($p1, $p2) -> $e1
                  | _ -> assert False ] >>
        | Some (tok, match_) ->
          <:expr< match $tok with
                  [ $pat:match_ -> $e1
                  | _ -> assert False ] >> ] in
      <:expr< fun ($locid : $uid:gm.Loc.t) -> $e2 >> in
    let (txt, _) =
      List.fold_left
        (fun (txt, i) s ->
          match s.pattern with
          [ None | Some <:patt< _ >> -> (<:expr< fun _ -> $txt >>, i)
          | Some <:patt< ($_ $(tup:<:patt< _ >>) as $p) >> ->
              let p = make_ctyp_patt s.styp tvar p in
              (<:expr< fun $p -> $txt >>, i)
          | Some p when Ast.is_irrefut_patt p ->
              let p = make_ctyp_patt s.styp tvar p in
              (<:expr< fun $p -> $txt >>, i)
          | Some _ ->
              let p = make_ctyp_patt s.styp tvar
                        <:patt< $(lid:"__camlp4_"^string_of_int i) >> in
              (<:expr< fun $p -> $txt >>, succ i) ])
        (e, 0) psl  in
    let txt =
      if meta_action.val then
        <:expr< Obj.magic $(MetaAst.Expr.meta_expr _loc txt) >>
      else txt  in
    <:expr< $uid:gm.Action.mk $txt >>
  ;

  (* use [text_of_action] to generate code
     FIXME: understand [rtvar] [tvar]
   *)  
  value srules loc (t:string) rl (tvar:string) =
    List.map
      (fun r ->
        let sl = [ s.text | s <- r.prod ] in
        let ac = text_of_action loc r.prod t r.action tvar in
        (sl, ac))
      rl
  ;

  value rec make_expr (entry:name Ast.expr) (tvar:string) = fun
    [ TXmeta _loc n tl e t ->
        let el =
          List.fold_right
            (fun t el -> <:expr< [$(make_expr entry "" t) :: $el] >>)
            tl <:expr< [] >> in
        <:expr<   $uid:gm.Smeta $str:n $el ($uid:gm.Action.mk $(make_ctyp_expr t tvar e)) >>
    | TXlist _loc min t ts ->
        let txt = make_expr entry "" t.text in
        match (min, ts) with
        [ (False, None) -> <:expr< $uid:gm.Slist0 $txt >>
        | (True, None) -> <:expr< $uid:gm.Slist1 $txt >>
        | (False, Some s) ->
            let x = make_expr entry tvar s.text in
            <:expr< $uid:gm.Slist0sep $txt $x >>
        | (True, Some s) ->
            let x = make_expr entry tvar s.text in
            <:expr< $uid:gm.Slist1sep $txt $x >> ]
    | TXnext _loc -> <:expr< $uid:gm.Snext >>
    | TXnterm _loc n lev ->
        match lev with
        [ Some lab ->
            <:expr<
              $uid:gm.Snterml
                ($uid:gm.Entry.obj ($(n.expr) : $uid:gm.Entry.t '$(n.tvar)))
                $str:lab >>
        | None ->
            if n.tvar = tvar then <:expr< $uid:gm.Sself >>
            else
              <:expr<
                $uid:gm.Snterm
                    ($uid:gm.Entry.obj ($(n.expr) : $uid:gm.Entry.t '$(n.tvar))) >> ]
    | TXopt _loc t -> <:expr< $uid:gm.Sopt $(make_expr entry "" t) >>
    | TXtry _loc t -> <:expr< $uid:gm.Stry $(make_expr entry "" t) >>
    | TXrules _loc rl ->
        <:expr< $uid:gm.srules $(entry.expr) $(make_expr_rules _loc entry rl "") >>
    | TXself _loc -> <:expr< $uid:gm.Sself >>
    | TXkwd _loc kwd -> <:expr< $uid:gm.Skeyword $str:kwd >>
    | TXtok _loc match_fun descr ->
        <:expr< $uid:gm.Stoken ($match_fun, $`str:descr) >> ]

  and make_expr_rules _loc n rl tvar =
    List.fold_left
      (fun txt (sl, ac) ->
        let sl =
          List.fold_right
            (fun t txt ->
                let x = make_expr n tvar t in
                <:expr< [$x :: $txt] >>)
            sl <:expr< [] >> in
        <:expr< [($sl, $ac) :: $txt ] >>)
      <:expr< [] >> rl ;

  value expr_of_delete_rule _loc n sl =
    let sl =
      List.fold_right
        (fun s e -> <:expr< [$(make_expr n "" s.text) :: $e ] >>) sl
        <:expr< [] >> in
    (<:expr< $(n.expr) >>, sl) ;

  value rec tvar_of_ident =  fun
    [ <:ident< $lid:x >> | <:ident< $uid:x >> -> x
    | <:ident< $uid:x.$xs >> -> x ^ "__" ^ tvar_of_ident xs
    | _ -> failwith "internal error in the Grammar extension" ] ;

  value mk_name _loc i =
    {expr = <:expr< $id:i >>; tvar = tvar_of_ident i; loc = _loc};

  value slist loc min sep symb = TXlist loc min symb sep ;
  (* [text_of_entry] *)  
  value text_of_entry _loc e =
    let ent =
      let x = e.name in
      let _loc = e.name.loc in
      <:expr< ($(x.expr) : $uid:gm.Entry.t '$(x.tvar)) >>   in
    let pos =
      match e.pos with
      [ Some pos -> <:expr< Some $pos >>
      | None -> <:expr< None >> ] in
    let txt =
      List.fold_right
        (fun level txt ->
          let lab =
            match level.label with
            [ Some lab -> <:expr< Some $str:lab >>
            | None -> <:expr< None >> ]  in
          let ass =
            match level.assoc with
            [ Some ass -> <:expr< Some $ass >>
            | None -> <:expr< None >> ]  in
          let txt =
            let rl = srules _loc e.name.tvar level.rules e.name.tvar in
            let e = make_expr_rules _loc e.name rl e.name.tvar in
            <:expr< [($lab, $ass, $e) :: $txt] >> in
          txt)
        e.levels <:expr< [] >> in
    (ent, pos, txt)
  ;
  (* [gl] is the name  list option *)   
  value let_in_of_extend _loc gram gl el args =
    match gl with
    [ None -> args
    | Some nl -> begin
        check_use nl el;
        let ll =
          let same_tvar e n = e.name.tvar = n.tvar in
          List.fold_right
            (fun e ll -> match e.name.expr with
              [ <:expr< $lid:_ >> ->
                    if List.exists (same_tvar e) nl then ll
                    else if List.exists (same_tvar e) ll then ll
                    else [e.name :: ll]
              | _ -> ll ])  el [] in
        let local_binding_of_name = fun
          [ {expr = <:expr< $lid:i >> ; tvar = x; loc = _loc} ->
            <:binding< $lid:i =  (grammar_entry_create $str:i : $uid:gm.Entry.t '$x) >>
          | _ -> failwith "internal error in the Grammar extension" ]  in
        let expr_of_name {expr = e; tvar = x; loc = _loc} =
          <:expr< ($e : $uid:gm.Entry.t '$x) >> in
        let e = match ll with
          [ [] -> args
          | [x::xs] ->
              let locals =
                List.fold_right
                  (fun name acc ->
                    <:binding< $acc and $(local_binding_of_name name) >>)
                  xs (local_binding_of_name x) in
              let entry_mk =  match gram with
              [ Some g -> <:expr< $uid:gm.Entry.mk $id:g >>
              | None   -> <:expr< $uid:gm.Entry.mk >> ] in <:expr<
              let grammar_entry_create = $entry_mk in
              let $locals in $args >> ] in
          match nl with
          [ [] -> e
          | [x::xs] ->
              let globals =
                List.fold_right
                  (fun name acc ->
                    <:binding< $acc and _ = $(expr_of_name name) >>)
                  xs <:binding< _ = $(expr_of_name x) >>
              in <:expr< let $globals in $e >> ]
        end ]
  ;

  class subst gmod =
    object
      inherit Ast.map as super;
      method ident =
        fun
        [ <:ident< $uid:x >> when x = gm -> gmod
        | x -> super#ident x ];
    end;

 (* replace ast [Camlp4Grammar__] with [gmod]  *)   
  value subst_gmod ast gmod = (new subst gmod)#expr ast;

  (* the [gl] is global entry name list, [el] is entry list
     [gram] is the grammar, [gmod] is the [Gram] module
   *)
  value text_of_functorial_extend _loc gmod gram gl el =
    let args =
      let el =
        List.map
          (fun e ->
            let (ent, pos, txt) = text_of_entry e.name.loc e in
            <:expr< $uid:gm.extend $ent ((fun () -> ($pos, $txt)) ()) >> ) el  in
      match el with
      [ [] -> <:expr< () >>
      | [e] -> e
      | [e::el] -> <:expr< do { $(List.fold_left (fun acc x -> <:expr< $acc; $x >>) e el) } >>  ]  in
    subst_gmod (let_in_of_extend _loc gram gl el args) gmod;

  value wildcarder = object (self)
    inherit Ast.map as super;
    method patt =
      fun
      [ <:patt@_loc< $lid:_ >> -> <:patt< _ >>
      | <:patt< ($p as $_) >> -> self#patt p
      | p -> super#patt p ];
  end;


    (*
    {[
      match s.pattern with
      [ Some <:patt< $uid:u $(tup:<:patt< _ >>) >> ->
      mk_tok _loc <:patt< $uid:u $p >> s.styp
      | _ -> { (s) with pattern = Some p } ]

      | "`"; p = patt -> mk_tok _loc p (STtok _loc)
      | x = UIDENT -> mk_tok _loc <:patt< $uid:x $(tup:<:patt< _ >>) >>  (STstring_tok _loc)
      | x = UIDENT; s = STRING -> mk_tok _loc <:patt< $uid:x $str:s >> (STtok _loc)
    ]}
   *)  
  value mk_tok _loc p t =
    let p' = wildcarder#patt p in
    let match_fun =
      if Ast.is_irrefut_patt p' then
        <:expr< fun [ $pat:p' -> True ] >>
      else
        <:expr< fun [ $pat:p' -> True | _ -> False ] >> in
    let descr = string_of_patt p' in
    let text = TXtok _loc match_fun descr in
    {used = []; text = text; styp = t; pattern = Some p };

  value symbol = Gram.Entry.mk "symbol";

  (* FIXME why deprecate such syntax *)  
  value check_not_tok s =
    match s with
    [ {text = TXtok _loc _ _ } ->
        Loc.raise _loc (Stream.Error
          ("Deprecated syntax, use a sub rule. "^
           "LIST0 STRING becomes LIST0 [ x = STRING -> x ]"))
    | _ -> () ];

  FanConfig.antiquotations.val := True;

  EXTEND Gram GLOBAL: expr symbol;
    expr: After "top"
      [ [ "EXTEND"; e = extend_body; "END" -> e
        | "DELETE_RULE"; e = delete_rule_body; "END" -> e ] ] ;
    extend_header:
      [ [ "("; i = qualid; ":"; t = t_qualid; ")" -> (Some i, t)
        | g = qualuid -> (None, g) ] ];
    extend_body:
      [ [ (gram, g) = extend_header; global_list = OPT global;
          el = LIST1 [ e = entry; semi_sep -> e ] ->
            text_of_functorial_extend _loc g gram global_list el ] ] ;
    delete_rule_body:
      [ [ g = qualuid; n = name; ":"; sl = LIST0 symbol SEP semi_sep ->
            let (e, b) = expr_of_delete_rule _loc n sl in
            subst_gmod <:expr< $uid:gm.delete_rule $e $b >> g ] ] ;
    qualuid:
      [ [ x = UIDENT; "."; xs = SELF -> <:ident< $uid:x.$xs >>
        | i = UIDENT -> <:ident< $uid:i >> ] ] ;
    qualid:
      [ [ x = UIDENT; "."; xs = SELF -> <:ident< $uid:x.$xs >>
        | i = UIDENT -> <:ident< $uid:i >>
        | i = LIDENT -> <:ident< $lid:i >> ] ];
    t_qualid:
      [ [ x = UIDENT; "."; xs = SELF -> <:ident< $uid:x.$xs >>
        | x = UIDENT; "."; `LIDENT "t" -> <:ident< $uid:x >> ] ] ;
    global:
      [ [ UIDENT "GLOBAL"; ":"; sl = LIST1 name; semi_sep -> sl ] ]
    ;
    entry:
      [ [ n = name; ":"; pos = OPT position; ll = level_list ->
            {name = n; pos = pos; levels = ll} ] ]
    ;
    position:
      [ [ `UIDENT ("First"|"Last" as x ) -> <:expr< FanSig.Grammar.$uid:x >>
        | `UIDENT ("Before" | "After" | "Level" as x) ; n = string -> <:expr< FanSig.Grammar.$uid:x $n >>
        ] ]
    ;
    level_list:
      [ [ "["; ll = LIST0 level SEP "|"; "]" -> ll ] ]
    ;
    level:
      [ [ lab = OPT [ x = STRING -> x ]; ass = OPT assoc; rules = rule_list ->
            {label = lab; assoc = ass; rules = rules} ] ]
    ;
    assoc:
      [
       [ `UIDENT ("LA"|"RA"|"NA" as x) -> <:expr< FanSig.Grammar.$uid:x >>
       | `UIDENT x -> failwithf "%s is not a correct associativity:(LA|RA|NA)" x 
      ] ]
    ;
    rule_list:
      [ [ "["; "]" -> []
        | "["; rules = LIST1 rule SEP "|"; "]" ->
            retype_rule_list_without_patterns _loc rules ] ]
    ;
    rule:
      [ [ psl = LIST0 psymbol SEP semi_sep; "->"; act = expr ->
            {prod = psl; action = Some act}
        | psl = LIST0 psymbol SEP semi_sep ->
            {prod = psl; action = None} ] ]
    ;
    psymbol:
      [ [ p = LIDENT; "="; s = symbol ->
            match s.pattern with
            [ Some (<:patt< $uid:u $(tup:<:patt< _ >>) >> as p') ->
                let match_fun = <:expr< fun [ $pat:p' -> True | _ -> False ] >> in
                let p' = <:patt< ($p' as $lid:p) >> in
                let descr = u ^ " _" in
                let text = TXtok _loc match_fun descr in
                { (s) with text = text; pattern = Some p' }
            | _ -> { (s) with pattern = Some <:patt< $lid:p >> } ]
        | i = LIDENT; lev = OPT [ UIDENT "Level"; s = STRING -> s ] ->
            let name = mk_name _loc <:ident< $lid:i >> in
            let text = TXnterm _loc name lev in
            let styp = STquo _loc i in
            {used = [i]; text = text; styp = styp; pattern = None}
        | p = pattern; "="; s = symbol ->
            match s.pattern with
            [ Some <:patt< $uid:u $(tup:<:patt< _ >>) >> ->
                mk_tok _loc <:patt< $uid:u $p >> s.styp
            | _ -> { (s) with pattern = Some p } ]
        | s = symbol -> s ] ]
    ;
    symbol:
      [ "top" NA
        [ `UIDENT ("LIST0"| "LIST1" as x); s = SELF; sep = OPT [ UIDENT "SEP"; t = symbol -> t ] ->
            let () = check_not_tok s in
            let used =  match sep with
              [ Some symb -> symb.used @ s.used
              | None -> s.used ]   in
            let styp = STapp _loc (STlid _loc "list") s.styp in
            let text = slist _loc
                (match x with ["LIST0" -> False | "LIST1" -> True | _ -> failwithf "only (LIST0|LIST1) allowed here"])  sep s in
            {used = used; text = text; styp = styp; pattern = None}
        | UIDENT "OPT"; s = SELF ->
            let () = check_not_tok s in
            let styp = STapp _loc (STlid _loc "option") s.styp in
            let text = TXopt _loc s.text in
            {used = s.used; text = text; styp = styp; pattern = None}
        | UIDENT "TRY"; s = SELF ->
            let text = TXtry _loc s.text in
            {used = s.used; text = text; styp = s.styp; pattern = None} ]
      | [ UIDENT "SELF" ->
            {used = []; text = TXself _loc; styp = STself _loc "SELF"; pattern = None}
        | UIDENT "NEXT" ->
            {used = []; text = TXnext _loc; styp = STself _loc "NEXT"; pattern = None}
        | "["; rl = LIST0 rule SEP "|"; "]" ->
            let rl = retype_rule_list_without_patterns _loc rl in
            let t = new_type_var () in
            {used = used_of_rule_list rl;
            text = TXrules _loc (srules _loc t rl "");
            styp = STquo _loc t; pattern = None}
        | "`"; p = patt -> mk_tok _loc p (STtok _loc)
        (* parsing UIDENT *)      
        | x = UIDENT -> mk_tok _loc <:patt< $uid:x $(tup:<:patt< _ >>) >>
                               (STstring_tok _loc)
        | x = UIDENT; s = STRING -> mk_tok _loc <:patt< $uid:x $str:s >> (STtok _loc)
              
        | x = UIDENT; `ANTIQUOT "" s ->
            let e = AntiquotSyntax.parse_expr _loc s in
            let match_fun = <:expr< fun [ $uid:x camlp4_x when camlp4_x = $e -> True | _ -> False ] >> in
            let descr = "$" ^ x ^ " " ^ s in
            let text = TXtok _loc match_fun descr in
            let p = <:patt< $uid:x $(tup:<:patt< _ >>) >> in
            {used = []; text = text; styp = STtok _loc; pattern = Some p }
        | s = STRING ->
            {used = []; text = TXkwd _loc s;
             styp = STtok _loc; pattern = None }
        | i = UIDENT; "."; il = qualid;
          lev = OPT [ UIDENT "Level"; s = STRING -> s ] ->
            let n = mk_name _loc <:ident< $uid:i.$il >> in
            {used = [n.tvar]; text = TXnterm _loc n lev;
            styp = STquo _loc n.tvar; pattern = None}
        | n = name; lev = OPT [ UIDENT "Level"; s = STRING -> s ] ->
            {used = [n.tvar]; text = TXnterm _loc n lev;
            styp = STquo _loc n.tvar; pattern = None}
        | "("; s_t = SELF; ")" -> s_t ] ]  ;
    pattern:
      [ [ i = LIDENT -> <:patt< $lid:i >>
        | "_" -> <:patt< _ >>
        | "("; p = pattern; ")" -> <:patt< $p >>
        | "("; p1 = pattern; ","; p2 = comma_patt; ")" -> <:patt< ( $p1, $p2 ) >>
      ] ]   ;
    comma_patt:
      [ [ p1 = SELF; ","; p2 = SELF -> <:patt< $p1, $p2 >>
        | p = pattern -> p
      ] ] ;
    name:
      [ [ il = qualid -> mk_name _loc il ] ]
    ;
    string:
      [ [ s = STRING -> <:expr< $str:s >>
        | `ANTIQUOT "" s -> AntiquotSyntax.parse_expr _loc s ] ] ;
    semi_sep:
      [ [ ";" -> () ] ] ;
  END;


  (*
  EXTEND Gram
    symbol: Level "top"
      [ NA
        [ min = [ UIDENT "SLIST0" -> False | UIDENT "SLIST1" -> True ];
          s = SELF; sep = OPT [ UIDENT "SEP"; t = symbol -> t ] ->
            sslist _loc min sep s
        | UIDENT "SOPT"; s = SELF ->
            ssopt _loc s ] ]
    ;
  END;
  *)

  value sfold _loc n foldfun f e s =
    let styp = STquo _loc (new_type_var ()) in
    let e = <:expr< $uid:gm.$lid:foldfun $f $e >> in
    let t = STapp _loc (STapp _loc (STtyp <:ctyp< $uid:gm.fold _ >>) s.styp) styp in
    {used = s.used; text = TXmeta _loc n [s.text] e t; styp = styp; pattern = None }
  ;

  value sfoldsep _loc n foldfun f e s sep =
    let styp = STquo _loc (new_type_var ()) in
    let e = <:expr< $uid:gm.$lid:foldfun $f $e >> in
    let t =
      STapp _loc (STapp _loc (STtyp <:ctyp< $uid:gm.foldsep _ >>) s.styp) styp
    in
    {used = s.used @ sep.used; text = TXmeta _loc n [s.text; sep.text] e t;
    styp = styp; pattern = None}
  ;

  EXTEND Gram
    GLOBAL: symbol;
    symbol: Level "top"
      [ [ UIDENT "FOLD0"; f = simple_expr; e = simple_expr; s = SELF ->
            sfold _loc "FOLD0" "sfold0" f e s
        | UIDENT "FOLD1"; f = simple_expr; e = simple_expr; s = SELF ->
            sfold _loc "FOLD1" "sfold1" f e s
        | UIDENT "FOLD0"; f = simple_expr; e = simple_expr; s = SELF;
          UIDENT "SEP"; sep = symbol ->
            sfoldsep _loc "FOLD0 SEP" "sfold0sep" f e s sep
        | UIDENT "FOLD1"; f = simple_expr; e = simple_expr; s = SELF;
          UIDENT "SEP"; sep = symbol ->
            sfoldsep _loc "FOLD1 SEP" "sfold1sep" f e s sep ] ]
    ;
    simple_expr:
      [ [ i = a_LIDENT -> <:expr< $lid:i >>
        | "("; e = expr; ")" -> e ] ]
    ;
  END;

  Options.add "-split_ext" (Arg.Set split_ext)
    "Split EXTEND by functions to turn around a PowerPC problem.";

  Options.add "-split_gext" (Arg.Set split_ext)
    "Old name for the option -split_ext.";

  Options.add "-meta_action" (Arg.Set meta_action)
    "Undocumented"; (* FIXME *)

end;
