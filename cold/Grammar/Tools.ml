let get_prev_loc_only = (ref false )

module Make =
                                       functor (Structure : Structure.S) ->
                                        struct
                                         open Structure

                                         let empty_entry =
                                          fun ename ->
                                           fun _ ->
                                            (raise (
                                              (Stream.Error
                                                ("entry [" ^ (
                                                  (ename ^ "] is empty") )))
                                              ))

                                         let rec stream_map =
                                          fun f ->
                                           fun (__strm :
                                             _ Stream.t) ->
                                            (match (Stream.peek __strm) with
                                             | Some (x) ->
                                                (
                                                (Stream.junk __strm)
                                                );
                                                let strm = __strm in
                                                (Stream.lcons (
                                                  fun _ -> (f x) ) (
                                                  (Stream.slazy (
                                                    fun _ ->
                                                     (stream_map f strm) ))
                                                  ))
                                             | _ -> Stream.sempty)

                                         let keep_prev_loc =
                                          fun strm ->
                                           (match (Stream.peek strm) with
                                            | None -> Stream.sempty
                                            | Some (tok0, init_loc) ->
                                               let rec go =
                                                fun prev_loc ->
                                                 fun strm1 ->
                                                  if !get_prev_loc_only then
                                                   (
                                                   (Stream.lcons (
                                                     fun _ ->
                                                      (tok0,
                                                       {prev_loc = prev_loc;
                                                        cur_loc = prev_loc;
                                                        prev_loc_only = true })
                                                     ) (
                                                     (Stream.slazy (
                                                       fun _ ->
                                                        (go prev_loc strm1)
                                                       )) ))
                                                   )
                                                  else
                                                   let (__strm :
                                                     _ Stream.t) =
                                                    strm1 in
                                                   (match
                                                      (Stream.peek __strm) with
                                                    | Some (tok, cur_loc) ->
                                                       (
                                                       (Stream.junk __strm)
                                                       );
                                                       let strm = __strm in
                                                       (Stream.lcons (
                                                         fun _ ->
                                                          (tok,
                                                           {prev_loc =
                                                             prev_loc;
                                                            cur_loc = cur_loc;
                                                            prev_loc_only =
                                                             false }) ) (
                                                         (Stream.slazy (
                                                           fun _ ->
                                                            (go cur_loc strm)
                                                           )) ))
                                                    | _ -> Stream.sempty) in
                                               (go init_loc strm))

                                         let drop_prev_loc =
                                          fun strm ->
                                           (stream_map (
                                             fun (tok, r) ->
                                              (tok, ( r.cur_loc )) ) strm)

                                         let get_cur_loc =
                                          fun strm ->
                                           (match (Stream.peek strm) with
                                            | Some (_, r) -> r.cur_loc
                                            | None -> Loc.ghost)

                                         let get_prev_loc =
                                          fun strm ->
                                           (
                                           (get_prev_loc_only := true )
                                           );
                                           let result =
                                            (match (Stream.peek strm) with
                                             | Some
                                                (_, {prev_loc = prev_loc;
                                                 prev_loc_only = true}) ->
                                                (
                                                (Stream.junk strm)
                                                );
                                                prev_loc
                                             | Some
                                                (_, {prev_loc = prev_loc;
                                                 prev_loc_only = false}) ->
                                                prev_loc
                                             | None -> Loc.ghost) in
                                           (
                                           (get_prev_loc_only := false )
                                           );
                                           result

                                         let is_level_labelled =
                                          fun n ->
                                           fun lev ->
                                            (match lev.lname with
                                             | Some (n1) -> (n = n1)
                                             | None -> (false))

                                         let warning_verbose = (ref true )

                                         let rec get_token_list =
                                          fun entry ->
                                           fun tokl ->
                                            fun last_tok ->
                                             fun tree ->
                                              (match tree with
                                               | Node
                                                  ({node =
                                                     ((Stoken (_)
                                                       | Skeyword (_)) as
                                                      tok); son = son;
                                                  brother = DeadEnd}) ->
                                                  (get_token_list entry (
                                                    ( last_tok ) :: tokl  )
                                                    tok son)
                                               | _ ->
                                                  if (tokl = [] ) then None 
                                                  else
                                                   (Some
                                                     ((
                                                      (List.rev (
                                                        ( last_tok ) :: tokl 
                                                        )) ), last_tok, tree)))

                                         let is_antiquot =
                                          fun s ->
                                           let len = (String.length s) in
                                           (( (len > 1) ) && (
                                             (( (String.get s 0) ) = '$') ))

                                         let eq_Stoken_ids =
                                          fun s1 ->
                                           fun s2 ->
                                            (( (not ( (is_antiquot s1) )) )
                                              && (
                                              (( (not ( (is_antiquot s2) )) )
                                                && ( (s1 = s2) )) ))

                                         let logically_eq_symbols =
                                          fun entry ->
                                           let rec eq_symbols =
                                            fun s1 ->
                                             fun s2 ->
                                              (match (s1, s2) with
                                               | (Snterm (e1), Snterm (e2)) ->
                                                  (( e1.ename ) = ( e2.ename
                                                    ))
                                               | (Snterm (e1), Sself) ->
                                                  (( e1.ename ) = (
                                                    entry.ename ))
                                               | (Sself, Snterm (e2)) ->
                                                  (( entry.ename ) = (
                                                    e2.ename ))
                                               | (Snterml (e1, l1),
                                                  Snterml (e2, l2)) ->
                                                  ((
                                                    (( e1.ename ) = (
                                                      e2.ename )) ) && (
                                                    (l1 = l2) ))
                                               | ((((Slist0 (s1), Slist0 (s2))
                                                    | (Slist1 (s1),
                                                       Slist1 (s2)))
                                                   | (Sopt (s1), Sopt (s2)))
                                                  | (Stry (s1), Stry (s2))) ->
                                                  (eq_symbols s1 s2)
                                               | ((Slist0sep (s1, sep1),
                                                   Slist0sep (s2, sep2))
                                                  | (Slist1sep (s1, sep1),
                                                     Slist1sep (s2, sep2))) ->
                                                  (( (eq_symbols s1 s2) ) &&
                                                    ( (eq_symbols sep1 sep2)
                                                    ))
                                               | (Stree (t1), Stree (t2)) ->
                                                  (eq_trees t1 t2)
                                               | (Stoken (_, s1),
                                                  Stoken (_, s2)) ->
                                                  (eq_Stoken_ids s1 s2)
                                               | _ -> (s1 = s2))
                                           and eq_trees =
                                            fun t1 ->
                                             fun t2 ->
                                              (match (t1, t2) with
                                               | (Node (n1), Node (n2)) ->
                                                  ((
                                                    (eq_symbols ( n1.node ) (
                                                      n2.node )) ) && (
                                                    ((
                                                      (eq_trees ( n1.son ) (
                                                        n2.son )) ) && (
                                                      (eq_trees ( n1.brother
                                                        ) ( n2.brother )) ))
                                                    ))
                                               | ((LocAct (_, _) | DeadEnd),
                                                  (LocAct (_, _) | DeadEnd)) ->
                                                  (true)
                                               | _ -> (false)) in
                                           eq_symbols

                                         let rec eq_symbol =
                                          fun s1 ->
                                           fun s2 ->
                                            (match (s1, s2) with
                                             | (Snterm (e1), Snterm (e2)) ->
                                                (e1 == e2)
                                             | (Snterml (e1, l1),
                                                Snterml (e2, l2)) ->
                                                (( (e1 == e2) ) && (
                                                  (l1 = l2) ))
                                             | ((((Slist0 (s1), Slist0 (s2))
                                                  | (Slist1 (s1), Slist1 (s2)))
                                                 | (Sopt (s1), Sopt (s2)))
                                                | (Stry (s1), Stry (s2))) ->
                                                (eq_symbol s1 s2)
                                             | ((Slist0sep (s1, sep1),
                                                 Slist0sep (s2, sep2))
                                                | (Slist1sep (s1, sep1),
                                                   Slist1sep (s2, sep2))) ->
                                                (( (eq_symbol s1 s2) ) && (
                                                  (eq_symbol sep1 sep2) ))
                                             | (Stree (_), Stree (_)) ->
                                                (false)
                                             | (Stoken (_, s1),
                                                Stoken (_, s2)) ->
                                                (eq_Stoken_ids s1 s2)
                                             | _ -> (s1 = s2))

                                        end
