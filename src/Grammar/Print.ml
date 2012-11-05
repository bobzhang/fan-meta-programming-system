open Structure;
open Format;
open LibUtil;
let pp = fprintf ;
  
type brothers = [ Bro of symbol and list brothers ];
type space_formatter =  format unit Format.formatter unit;
      
class text_grammar= object(self:'self)
  method tree f t = self#rules f  (flatten_tree t);
  method list :  ! 'a .
      ?sep:space_formatter -> ?first:space_formatter ->
      ?last:space_formatter -> (Format.formatter -> 'a -> unit) ->
        Format.formatter ->  list 'a -> unit
            = fun  ?sep ?first  ?last fu f xs -> 
              let first = match first with [Some x -> x | None -> ""]
              and last = match last with [Some x -> x | None -> ""]
              and sep = match sep with [Some x -> x | None -> "@ "] in
              let aux f = fun
                [ [] -> ()
                | [x] -> fu f x
                | xs ->
                let rec loop  f = fun
                  [ [x] -> fu f x
                  | [x::xs] ->  pp f "%a%(%)%a" fu x sep loop xs 
                  | _ -> assert false ] in begin
                      pp f "%(%)%a%(%)" first loop xs last;
                  end ] in
          aux f xs;
  method option : ! 'a . ?first:space_formatter -> ?last:space_formatter ->
    (Format.formatter -> 'a -> unit) -> Format.formatter ->  option 'a -> unit =
      fun  ?first  ?last fu f a ->
        let first = match first with [Some x -> x | None -> ""]
        and last = match last with [Some x -> x | None -> ""]  in
        match a with
        [ None -> ()
        | Some x -> pp f "%(%)%a%(%)" first fu x last];
  method symbol f =  fun
    [ `Smeta n sl _ -> self#meta n f  sl
    | `Slist0 s -> pp f "LIST0 %a" self#symbol1 s
    | `Slist0sep s t ->
        pp f "LIST0 %a SEP %a" self#symbol1 s self#symbol1 t
    | `Slist1 s -> pp f "LIST1 %a" self#symbol1 s
    | `Slist1sep s t ->
        pp f "LIST1 %a SEP %a" self#symbol1 s self#symbol1 t
    | `Sopt s -> pp f "OPT %a" self#symbol1 s
    | `Stry s -> pp f "TRY %a" self#symbol1 s
    | `Snterml e l -> pp f "%s@ Level@ %S" e.ename l
    | `Snterm _ | `Snext | `Sself | `Stree _ | `Stoken _ | `Skeyword _ as s ->
        self#symbol1 f s ];
  method meta ns f  sl=
    match ns with
    [ [x] ->
       pp f "%s@;%a" x (self#list self#symbol ) sl
    | [x;y] ->
        let l = List.length sl in
        let (a,b) = List.split_at (l-1) sl in 
        pp f "%s@;%a@;%s@;%a" x (self#list self#symbol) a y  (self#list self#symbol) b
    | _ -> invalid_arg "meta in print" ]  ;
  method description f = fun
    [ `Normal -> ()
    | `Antiquot -> pp f "$"];
  method symbol1 f = fun
    [ `Snterm e -> pp f "%s" e.ename
    | `Sself -> pp f "%s" "SELF"
    | `Snext -> pp f "%s" "NEXT" 
    | `Stoken (_, (description,content)) ->
        pp f "%a%s" self#description description content
    | `Skeyword s -> pp f "%S" s
    | `Stree t -> self#tree f t
    | `Smeta _ _ _ | `Snterml _ _ | `Slist0 _ | `Slist0sep _ _ | `Slist1 _ |
      `Slist1sep _ _ | `Sopt _ | `Stry _ as s -> pp f "(%a)" self#symbol s ];
  method rule f symbols= 
    pp f "@[<0>%a@]" (self#list self#symbol ~sep:";@ ") symbols;
  method rules f  rules= begin
    pp f "@[<hv0>[ %a]@]" (self#list self#rule ~sep:("@;| ")) rules
  end;
  method level f  = fun [ {assoc;lname;lsuffix;lprefix} ->
    (* [lsuffix] [lprefix] *)
    let rules = [ [`Sself::t] | t <- flatten_tree lsuffix] @ flatten_tree lprefix in 
    pp f "%a %a@;%a" (self#option (fun f s -> pp f "%S" s)) lname self#assoc assoc self#rules rules ];
  method assoc f = fun
    [ `LA -> pp f "LA"
    | `RA -> pp f "RA"
    | `NA -> pp f "NA" ];
    
  method levels f elev:unit =
    pp f "@[<hv0>  %a@]" (self#list self#level ~sep:"@;| ") elev;
  method entry f e :unit= begin
    pp f "@[<2>%s:@;[%a]@]" e.ename
      (fun f e ->
        match e.edesc with
        [Dlevels elev -> self#levels f elev
        |Dparser _ -> pp f "<parser>"]
      ) e
  end;
end;


let rec get_brothers acc =  fun
  [ DeadEnd | LocAct _ -> List.rev acc
  | Node {node = n; brother = b; son = s} ->
          get_brothers [ Bro n (get_brothers [] s) :: acc] b ];

let rec get_children acc =  fun
  [ [] -> List.rev acc
  | [Bro n x] -> get_children [n::acc] x
  | _ -> raise Exit ] ;
  
class dump_grammar = object(self:'self)
  inherit text_grammar ;
  method! tree f tree =
    let rec print_brothers f brothers =
      if brothers = [] then
        pp f "@ []"
      else
        List.iter (fun [ Bro n xs -> begin
          pp f "@ @[<hv2>- %a" self#symbol n;
          match xs with
          [ [] -> ()
          | [_] -> try print_children f (get_children [] xs)
                   with [ Exit -> pp f ":%a" print_brothers xs ]
          | _ -> pp f ":%a" print_brothers xs ];
          pp f "@]";
        end]) brothers
    and print_children f = List.iter (pp f ";@ %a" self#symbol) in 
    print_brothers f (get_brothers [] tree);
  method! level f = fun [{assoc;lname;lsuffix;lprefix} ->
    pp f "%a %a@;@[<hv2>suffix:@;%a@]@;@[<hv2>prefix:@;%a@]"
      (self#option (fun f s -> pp f "%S" s)) lname
      self#assoc assoc
      self#tree lsuffix
      self#tree lprefix ];
end;
let text = new text_grammar;
let dump = new dump_grammar;
    
