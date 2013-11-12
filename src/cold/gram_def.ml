open FAst
type name =  {
  id: vid;
  tvar: string;
  loc: loc} 
type styp =
  [ vid' | `App of (loc* styp* styp)
  | `Quote of (loc* position_flag* alident) | `Self of loc | `Type of ctyp] 
type entry =  {
  name: name;
  pos: exp option;
  local: bool;
  level: level} 
and level =  {
  label: string option;
  assoc: exp option;
  rules: rule list} 
and rule =  {
  env: (locid* exp) list;
  prod: osymbol list;
  action: exp option} 
and label = string option 
and kind =  
  | KNone
  | KSome
  | KNormal 
and locid = (loc* string) 
and symbol =  {
  text: text;
  styp: styp;
  bounds: (locid* label) list} 
and 'a decorate =  {
  kind: kind;
  txt: 'a} 
and osymbol = 
  {
  text: text;
  styp: styp;
  bounds: (locid* label) list;
  outer_pattern: locid option} 
and text =  
  | List of (loc* bool* osymbol* osymbol option)
  | Nterm of (loc* name* int option)
  | Try of (loc* text)
  | Peek of (loc* text)
  | Self of loc
  | Keyword of (loc* string)
  | Token of (loc* exp) 
type entries =  {
  items: entry list;
  gram: vid option;
  safe: bool} 
