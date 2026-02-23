{$h+}
{$mode objfpc}
unit base;

interface

const
  tab   = chr (9);
  eotch = chr (26);
  eolch = chr (13);

type
  yuvar   = (yucap,yulow,yunorm);
  twochar = string[2];

  stringproc = procedure (name:string);

  date = record
           d,m,y : integer
         end;

const
  yunum = 5;
  yu : array [yuvar,1..yunum] of string[2] = (('Š','Č','Ć','Đ','Ž'),('š','č','ć','đ','ž'),('s','c','c','dj','z'));



  function hash (s:string) : word;

  procedure error (s:string);

  function cleanstr (o:string) : string;
  function nospstr  (o:string) : string;

  function chcount        (ch,o:string) : integer;
  function mostfrequentch (list,s:string) : char;

  function utfnorm   (s:string) : string;
  function utflow    (s:string) : string;
  function utfscase  (s:string) : string;
  function utfupcase (s:string) : string;

  function allnumbers (s:string)   : boolean;
  function startswith (s,p:string) : boolean;

  function strfromreal (r:real)    : string;
  function strfromint  (i:integer) : string;
  function intfromstr  (s:string)  : integer;

  function  strfromdate (d,m,y:integer) : string;
  procedure datefromstr (var d,m,y:integer; s:string; var err:boolean; rev:boolean = false);

  function validjmbg (s:string)    : boolean;

  procedure traverse (pattern:string; process: stringproc);

  function signif (asr1,asr2,err1,err2:real) : integer;


implementation

uses
  sysutils, math;


  function signif (asr1,asr2,err1,err2:real) : integer;
  const
    c1 = 2.58;
    c5 = 1.96;
  var
    x : real;
    lb,ub : real;

  begin
    if (asr1=asr2) or (asr2=0) or (asr1=0)
    then signif := 0
    else begin
            x := (asr1-asr2)/sqrt(sqr(err1)+sqr(err2));
            lb := power (asr1/asr2,1-c1/x);
            ub := power (asr1/asr2,1+c1/x);
            if (lb<=1) and (ub>=1)
            then if asr1<asr2
                 then signif := -2
                 else signif := +2
            else begin
                   lb := power (asr1/asr2,1-c5/x);
                   ub := power (asr1/asr2,1+c5/x);
                   if (lb<=1) and (ub>=1)
                   then if asr1<asr2
                        then signif := -1
                        else signif := +1
                   else signif := 0
                 end
         end
  end;

  function hash (s:string) : word;
  var l:byte; i,j:integer; h:word;
     function w (pos:byte) : word;
     var mix : record case boolean of true:(b1,b2:byte); false:(w:word) end;
     begin
       mix.b1 := ord(s[pos]);
       mix.b2 := ord(s[pos+1]);
       w := mix.w
     end;
  begin
    l := length(s); s := s+chr(29);
    i := 1;
    j := 1;
    h := l;
    while i <= l do
    begin
      h := h xor rolword (w(i), (j+4) mod 16);
      i := i+2;
      j := j+1
    end;
    hash := h //mod hashtablesize
  end;

  procedure error (s:string);
  begin
    writeln ('error: ',s);
    halt (1)
  end;

  function cleanstr (o:string) : string;
  var ch:char; s:string; ol,i:integer;
  begin
    s := '';
    i := 1;
    ol := length(o);
    while i <= ol do
    begin
      ch := o[i];
      if (i<ol) and
          (ord(o[i])   = $c2) and
          (ord(o[i+1]) = $a0) {c2 a0 utf-8 non braking space}
          then begin ch := ' '; i := i+1 end;

      if ch<>' '
      then s := s+ch
      else if s<>''
           then if (i+1) <= ol
                then if o[i+1] <> ' '
                     then s := s+' ';
      i := i+1
    end;
    cleanstr := utflow(s)
  end;

  function nospstr (o:string) : string;
  var s:string; i:integer;
  begin
    s := '';
    for i := 1 to length(o) do
      if o[i]<>' '
      then s := s+o[i];
    nospstr := s
  end;

  function chcount  (ch,o:string) : integer;
  var
    i,n : integer;
  begin
    n := 0;
    for i := 1 to length(o) do
      if o[i]=ch then n := n+1;
    chcount := n
  end;

  function utfnorm (s:string) : string;
  var
    ns  : string;
    chs : twochar;
    i   : integer;

    function utfnormch (pos:integer) : twochar;
    var
      p : integer;
      i : integer;
    begin
      p := 0;
      for i := 1 to yunum do
        if (yu[yucap,i][1]=s[pos]) and (yu[yucap,i][2]=s[pos+1])
        then p := i
        else if (yu[yulow,i][1]=s[pos]) and (yu[yulow,i][2]=s[pos+1])
             then p := i;
      if p = 0
      then utfnormch := ''
      else utfnormch := yu[yunorm,p]
    end;

  begin
    ns := '';
    i := 1;
    while i<=length(s) do
    begin
      chs := utfnormch(i);
      if chs <> ''
      then begin ns := ns + chs;             i := i+2 end
      else begin ns := ns + lowercase(s[i]); i := i+1 end
    end;
    utfnorm := ns
  end;

  function utflow (s:string) : string;
  var
    ns  : string;
    chs : twochar;
    i   : integer;

    function utflowch (pos:integer) : twochar;
    var
      p : integer;
      i : integer;
    begin
      p := 0;
      for i := 1 to yunum do
        if (yu[yucap,i][1]=s[pos]) and (yu[yucap,i][2]=s[pos+1])
        then p := i
        else if (yu[yulow,i][1]=s[pos]) and (yu[yulow,i][2]=s[pos+1])
             then p := i;
      if p = 0
      then utflowch := ''
      else utflowch := yu[yulow,p]
    end;

  begin
    ns := '';
    i := 1;
    while i<=length(s) do
    begin
      chs := utflowch(i);
      if chs <> ''
      then begin ns := ns + chs;             i := i+2 end
      else begin ns := ns + lowercase(s[i]); i := i+1 end
    end;
    utflow := ns
  end;

  function utfscase (s:string) : string;
  var
    ns  : string;
    chs : twochar;
    i   : integer;

    function utflowch (pos:integer) : twochar;
    var
      p : integer;
      i : integer;
    begin
      p := 0;
      for i := 1 to yunum do
        if (yu[yucap,i][1]=s[pos]) and (yu[yucap,i][2]=s[pos+1])
        then p := i
        else if (yu[yulow,i][1]=s[pos]) and (yu[yulow,i][2]=s[pos+1])
             then p := i;
      if p = 0
      then utflowch := ''
      else utflowch := yu[yulow,p]
    end;

    function utfhighch (pos:integer) : twochar;
    var
      p : integer;
      i : integer;
    begin
      p := 0;
      for i := 1 to yunum do
        if (yu[yulow,i][1]=s[pos]) and (yu[yulow,i][2]=s[pos+1])
        then p := i
        else if (yu[yucap,i][1]=s[pos]) and (yu[yucap,i][2]=s[pos+1])
             then p := i;
      if p = 0
      then utfhighch := ''
      else utfhighch := yu[yucap,p]
    end;

  begin
    ns := '';
    i := 1;
    while i<=length(s) do
    begin
      if i = 1
      then chs := utfhighch(i)
      else chs := utflowch(i);

      if (chs <> '')
      then begin
             ns := ns + chs;
             i := i+2
           end
      else begin
             if i=1
             then ns := ns + uppercase(s[i])
             else ns := ns + s[i]; i := i+1
           end
    end;
    utfscase := ns
  end;

  function utfupcase (s:string) : string;
  var
    ns  : string;
    chs : twochar;
    i   : integer;

    function utflowch (pos:integer) : twochar;
    var
      p : integer;
      i : integer;
    begin
      p := 0;
      for i := 1 to yunum do
        if (yu[yucap,i][1]=s[pos]) and (yu[yucap,i][2]=s[pos+1])
        then p := i
        else if (yu[yulow,i][1]=s[pos]) and (yu[yulow,i][2]=s[pos+1])
             then p := i;
      if p = 0
      then utflowch := ''
      else utflowch := yu[yulow,p]
    end;

    function utfhighch (pos:integer) : twochar;
    var
      p : integer;
      i : integer;
    begin
      p := 0;
      for i := 1 to yunum do
        if (yu[yulow,i][1]=s[pos]) and (yu[yulow,i][2]=s[pos+1])
        then p := i
        else if (yu[yucap,i][1]=s[pos]) and (yu[yucap,i][2]=s[pos+1])
             then p := i;
      if p = 0
      then utfhighch := ''
      else utfhighch := yu[yucap,p]
    end;

  begin
    ns := '';
    i := 1;
    while i<=length(s) do
    begin
      chs := utfhighch(i);

      if (chs <> '')
      then begin
             ns := ns + chs;
             i := i+2
           end
      else begin
             ns := ns + uppercase(s[i]);
             i := i+1
           end
    end;
    utfupcase := ns
  end;

  function startswith (s,p:string) : boolean;
  var
    b:boolean;
  begin
    b := length(s)>=length(p);
    if b
    then b := copy (s,1,length(p)) = p;
    startswith := b
  end;

  function allnumbers (s:string) : boolean;
  var
    i:integer; b:boolean;
  begin
    b := length(s)<>0;
    for i := 1 to length(s) do
      if not (s[i] in ['0'..'9'])
      then b := false;
    allnumbers := b
  end;

  function intfromstr (s:string) : integer;
  var b:boolean; i:integer; n:integer;
  begin
    b := length(s)<>0;
    n := 0;
    for i := 1 to length(s) do
      if not (s[i] in ['0'..'9'])
      then b := false
      else n := n*10 + ord(s[i])-ord('0');

    if not b
    then intfromstr := -1
    else intfromstr := n
  end;

  function strfromreal (r:real) : string;
  var
    s : string[10];
  begin
    str (r:6:1,s);
    strfromreal := trim(s);
  end;

  function strfromint (i:integer) : string;
  var
    s : string[10];
  begin
    str (i,s);
    strfromint := s;
  end;


  function strfromdate (d,m,y:integer) : string;
    function z2(i:integer):string;
    begin
      if i<10
      then z2 := '0'+strfromint(i)
      else z2 := strfromint(i)
    end;
  begin
    strfromdate := z2(d)+'.'+z2(m)+'.'+strfromint(y)
  end;

  function okdate (jmbg:string) : boolean;
  var
    d,m,y:integer; err:boolean;
  begin
    datefromstr (d,m,y,copy(jmbg,1,2)+'-'+copy(jmbg,3,2)+'-'+copy(jmbg,5,3),err);
    okdate := not err and (y>1800) and (y<2100) and (d<>0) and (m<>0)
  end;

  procedure datefromstr (var d,m,y:integer; s:string; var err:boolean; rev:boolean = false);
  var
    pos : integer;
    ch  : char;
    i   : integer;

    function digit : boolean;
    begin
      digit := ch in ['0'..'9']
    end;

    function letter : boolean;
    begin
      letter := ch in ['a'..'z']
    end;

    function elch : boolean;
    begin
      elch := digit or letter
    end;

    procedure getch;
    begin
      if pos>length(s)
      then ch := eolch
      else begin
             ch := s[pos];
             pos := pos+1
           end
    end;

    procedure getnum;
    var
      p : integer;
      s : string;
    begin
      p := 0;
      s := '';
      while (ch in ['0'..'9']) do
      begin
        p := p+1;
        s := s+ch;
        getch
      end;
      i := intfromstr (s)
    end;

    procedure skipsep;
    begin
      if not elch then getch
    end;

    procedure getmonth;
    var
      s : string;
    begin
      case ch of
        'a'..'z' : begin
                     s := '';
                     repeat
                       s := s+ch;
                       getch
                     until not (ch in ['a'..'z']);
                     case s of
                       'jan','januar'   : i :=  1;
                       'feb','februar'  : i :=  2;
                       'mar','mart'     : i :=  3;
                       'apr','april'    : i :=  4;
                       'may','maj'      : i :=  5;
                       'jun','juni'     : i :=  6;
                       'jul','juli'     : i :=  7;
                       'aug','avgust'   : i :=  8;
                       'sep','sptembar' : i :=  9;
                       'oct','oktobar'  : i := 10;
                       'nov','novembar' : i := 11;
                       'dec','decembar' : i := 12
                       else i := -1
                     end
                   end;
        '0'..'9' : getnum;
        else i := -1
      end
    end;

  begin
    err := false;
    pos := 1; getch;

    if not digit
    then begin {month-y}
           d := 0;
           getmonth;
           skipsep;
           m := i;

           getnum;
           y := i
         end
    else begin

           getnum;
           skipsep;
           d := i;

           getmonth;
           skipsep;
           m := i;

           getnum;
           y := i;

           if (m<>-1) and (y<>-1) and (d>1900) // !!! krpez za yyy-mm-dd
           then begin
                  i := d;
                  d := y;
                  y := i
                end
           else begin
                  if (d<>0) and (m=-1) and (y=-1)
                  then begin
                          y := d;
                          m := 0;
                          d := 0
                        end;

                   if (d<>0) and (m<>0) and (y=-1)
                   then begin
                          y := m;
                          m := d;
                          d := 0
                        end
                end
         end;

    if ch='.' then getch; {. behind year}

    if rev
    then begin
           i := d;
           d := m;
           m := i
         end;

    if not (ch in [' ',',','g',eolch])
    then err := true
    else begin
           if (y>=0) and (y<=50) then y := y+2000;
           if (y>50) and (y<100) then y := y+1900;
           if (y>100) and (y<1000) then y := y+1000;

           err := not (d in [0..31]) or not (m in [0..12]) or (y<1800) or (y>2999)
         end

  end;



  function validjmbg (s:string) : boolean;
  var i : byte; wsum : integer;
  begin
    if (length(s)<>13) or not allnumbers(s) // or (s='1505936255017') đorđije roganović
    then validjmbg := false
    else if not okdate(s)
         then validjmbg := false
         else begin
                wsum := 0;
                for i := 1 to 6 do
                  wsum := wsum + (8-i) * (ord(s[i])+ord(s[i+6])-2*ord('0'));
                i := 11 - wsum mod 11;
                if  i > 9
                then validjmbg := s[13] = '0'
                else validjmbg := s[13] = chr(ord('0') + i)
              end
  end;

  procedure traverse (pattern:string; process: stringproc);
  var
    res : tsearchrec;
    path, name : string;
    fileattr : longint;
    attr : integer;
   begin
     attr := faAnyFile;
     if findfirst (pattern, attr, res) = 0 then
     begin
        path := extractfiledir (pattern);
        repeat
           name := path + '/'+ res.name;
           fileattr := filegetattr (name);
           writeln (fileattr, ' *** ' res.name);
           if fileattr and faDirectory = 0
           then process (name)
        until findnext(res) <> 0
     end;
     findclose (res)
  end;


  function mostfrequentch (list,s:string) : char;
  var
    i,j,max,num : integer;
    ch : char;
  begin
    ch := tab;
    max := 0;
    for i := 1 to length (list) do
    begin
      num := 0;
      for j := 1 to length(s) do
        if s[j]=list[i] then num := num+1;
      if num>max
      then begin
            max := num;
            ch := list[i]
           end
    end;
    mostfrequentch := ch
  end;

begin
end.