module MetaLocVar : FanAst.META_LOC =
  struct
    let meta_loc_patt _loc _ =
      `Id (_loc, (`Lid (_loc, (FanLoc.name.contents))))
    let meta_loc_expr _loc _ =
      `Id (_loc, (`Lid (_loc, (FanLoc.name.contents))))
  end 
module MetaLoc : FanAst.META_LOC =
  struct
    let meta_loc_patt _loc _location =
      failwith "MetaLoc.meta_loc_patt not implemented yet"
    let meta_loc_expr _loc location =
      let (a,b,c,d,e,f,g,h) = FanLoc.to_tuple location in
      `App
        (_loc,
          (`Id
             (_loc,
               (`Dot
                  (_loc, (`Uid (_loc, "FanLoc")), (`Lid (_loc, "of_tuple")))))),
          (`Tup
             (_loc,
               (`Com
                  (_loc, (`Str (_loc, (String.escaped a))),
                    (`Com
                       (_loc,
                         (`Com
                            (_loc,
                              (`Com
                                 (_loc,
                                   (`Com
                                      (_loc,
                                        (`Com
                                           (_loc,
                                             (`Com
                                                (_loc,
                                                  (`Int
                                                     (_loc,
                                                       (string_of_int b))),
                                                  (`Int
                                                     (_loc,
                                                       (string_of_int c))))),
                                             (`Int (_loc, (string_of_int d))))),
                                        (`Int (_loc, (string_of_int e))))),
                                   (`Int (_loc, (string_of_int f))))),
                              (`Int (_loc, (string_of_int g))))),
                         (if h
                          then `Id (_loc, (`Lid (_loc, "true")))
                          else `Id (_loc, (`Lid (_loc, "false")))))))))))
  end 
module MetaGhostLoc : FanAst.META_LOC =
  struct
    let meta_loc_patt _loc _ =
      failwith "MetaGhostLoc.meta_loc_patt not implemented"
    let meta_loc_expr _loc _ =
      `Id
        (_loc,
          (`Dot (_loc, (`Uid (_loc, "FanLoc")), (`Lid (_loc, "ghost")))))
  end 