open Format
open LibUtil
open Lib
module Ast = Camlp4Ast
open FSig
let transform =
  let _loc = FanLoc.ghost in
  let open Lib.Ident in
    function
    | `Pre pre ->
        (fun x  -> Ast.ExId (_loc, (ident_map (fun x  -> pre ^ x) x)))
    | `Post post ->
        (fun x  -> Ast.ExId (_loc, (ident_map (fun x  -> x ^ post) x)))
    | `Fun f -> (fun x  -> Ast.ExId (_loc, (ident_map f x)))
    | `Last f -> (fun x  -> Ast.ExId (_loc, (ident_map_of_ident f x)))
    | `Ident f -> (fun x  -> Ast.ExId (_loc, (f x)))
    | `Idents f -> (fun x  -> Ast.ExId (_loc, (f (list_of_acc_ident x []))))
    | `Obj f ->
        (function
         | Ast.IdLid (_loc,x) ->
             Ast.ExSnd
               (_loc, (Ast.ExId (_loc, (Ast.IdLid (_loc, "self")))), (f x))
         | t ->
             let dest = map_to_string t in
             let src = Lib.Ident.to_string.contents t in
             (if not (Hashtbl.mem Basic.conversion_table src)
              then
                (Hashtbl.add Basic.conversion_table src dest;
                 eprintf "Warning:  %s ==>  %s ==> unknown\n" src dest)
              else ();
              Ast.ExSnd
                (_loc, (Ast.ExId (_loc, (Ast.IdLid (_loc, "self")))),
                  (f dest))))
let basic_transform =
  function
  | `Pre pre -> (fun x  -> pre ^ x)
  | `Post post -> (fun x  -> x ^ post)
  | `Fun f -> f
let right_transform =
  let _loc = FanLoc.ghost in
  function
  | #basic_id_transform as x ->
      let f = basic_transform x in
      (fun x  -> Ast.ExId (_loc, (Ast.IdLid (_loc, (f x)))))
  | `Exp f -> f