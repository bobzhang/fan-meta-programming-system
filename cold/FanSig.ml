type ('a ,'loc )stream_filter = 
(('a *'loc ) Stream.t  -> ('a *'loc ) Stream.t )  
type quotation = 
{ q_name: string ; q_loc: string ; q_shift: int ; q_contents: string } 
type token = 
[
  `KEYWORD of  string |`SYMBOL of  string |`LIDENT of  string |`UIDENT of 
                                                                 string |
  `ESCAPED_IDENT of  string |`INT of ( int * string )|`INT32 of
                                                        ( int32 * string )|
  `INT64 of ( int64 * string )|`NATIVEINT of ( nativeint * string )|`FLOAT of
                                                                    ( float *
                                                                    string )|
  `CHAR of ( char * string )|`STRING of ( string * string )|`LABEL of  string |
  `OPTLABEL of  string |`QUOTATION of  quotation |`ANTIQUOT of
                                                    ( string * string )|
  `COMMENT of  string |`BLANKS of  string |`NEWLINE|`LINE_DIRECTIVE of
                                                      ( int * string  option
                                                        )|`EOI] 
type token_filter =  ( token , FanLoc.t ) stream_filter  
type filter =  { is_kwd:( string  ->  bool ) ;mutable  filter: token_filter } 