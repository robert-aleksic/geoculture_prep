{$h+}
{$mode objfpc}
unit csv;

interface

uses
  sysutils, base;

const
  maxcolumns = 200;

type
  csvrecordref = ^csvrecord;
  csvrecord = record
                col : array [1..maxcolumns] of ansistring;
                num : integer
              end;

  csvfile = record
              fn        : string;
              plainname : string;

              ft : text;

              eot : boolean;

              colnum  : integer;
              recnum  : integer;

              strict    : boolean;
              delimiter : char;

              rec     : csvrecord;
              headers : csvrecord;

              maxflen : array [1..maxcolumns] of integer;

              ch, nextch : char
            end;

  procedure csvreset (var cf:csvfile; fname:string; var h:csvrecord; isstrict:boolean=true);
  procedure csvreset (var cf:csvfile; fname:string; isstrict:boolean=true; h:csvrecordref=nil);
  procedure csvget   (var cf : csvfile; getheaders : boolean = false);
  procedure csvclose (var cf : csvfile);

  procedure csvheadersstart (name : string = ''; lens : boolean = true);
  procedure csvheadersstop;

implementation

var
  outputheaders    : boolean;
  headersfile      : string;
  showfieldlengths : boolean;


  procedure csvheadersstart (name:string = ''; lens : boolean = true);
  var
    f : text;
  begin
    outputheaders    := true;
    showfieldlengths := lens;
    if name<>''
    then begin
           headersfile := name;
           assign (f,headersfile);
           rewrite (f);
           close (f)
        end
  end;

  procedure csvheadersstop;
  begin
    outputheaders := false;
  end;

  procedure buffch (var cf:csvfile);
  begin
    with cf do
      if eof(ft)
      then nextch := eotch
      else if not eoln (ft)
           then read (ft,nextch)
           else begin
                  nextch := eolch;
                  readln (ft)
                end
  end;

  procedure getch (var cf:csvfile);
  begin
    cf.ch := cf.nextch;
    buffch (cf)
  end;

  procedure csvreset (var cf:csvfile; fname:string; var h:csvrecord; isstrict:boolean=true);
  begin
    csvreset (cf,fname,isstrict,@h);
  end;

  procedure csvreset (var cf:csvfile; fname:string; isstrict:boolean=true; h:csvrecordref=nil);

  const
    separators = '|;!'+tab;

  var
    s : string;
    i : integer;

  begin
    with cf do
    begin
      assign (ft,fname);

      reset (ft);
      readln (ft,s);
      delimiter := mostfrequentch (separators,s);
      close (ft);

      reset (ft);

      fn := fname;

      plainname := fn;
      i := pos ('/',plainname);
      while i>1 do
      begin
        plainname := copy (plainname,i+1,length(plainname)-i);
        i := pos ('/',plainname)
      end;
      i := pos ('.',plainname);
      if i>0
      then plainname := copy (plainname,1,i-1);

      eot := eof (ft);

      colnum := 0;
      recnum := 0;

      strict := isstrict;

      buffch (cf);

      for i := 1 to maxcolumns do
        maxflen[i] := 0;

      if eot
      then begin
             headers.num := 0;
             colnum := 0
           end
      else if h=nil
           then csvget (cf, true)
           else begin
                  headers := h^;
                  colnum  := headers.num
                end
    end
  end;

  procedure csvget (var cf : csvfile; getheaders : boolean = false);

    procedure getfield (var s:ansistring);

      procedure getuntil (endch:char);
      var quote : boolean;
        function last : boolean;
        begin
          with cf do
            if ch=eotch
            then last := true
            else if not quote
                 then last := ch in [eolch,endch]
                 else last := (ch='"') and (nextch in [eolch,eotch,delimiter])
        end;
      begin
        quote := endch='"';
        with cf do
          while not last do
          begin
            if ch=eolch
            then s := s+'\n'
            else s := s+ch;

            getch (cf);
          end
      end;
    begin
      with cf do
      begin
        getch (cf);
        if ch='=' then getch (cf);

        s := '';
        if ch<>'"'
        then getuntil (delimiter)
        else begin
               getch (cf);
               getuntil ('"');
               if ch='"' then getch(cf)
             end;
        s := trim(s)
      end
    end;

    procedure getuntileol;
    begin
      with cf do
      begin
        rec.num := 0;
        repeat
          rec.num := rec.num+1;
          getfield (rec.col[rec.num]);
        until (ch=eolch) or (ch=eotch);
      end
    end;

  var
    i : integer;
  begin
    with cf do
    begin
      if getheaders
      then begin
             getuntileol;
             while rec.col[rec.num]='' do // strip last empty fields from header
               rec.num := rec.num-1;
             colnum := rec.num;
           end
      else begin
             recnum := recnum+1;

             if not strict
             then getuntileol
             else begin
                    for i := 1 to colnum do
                      getfield (rec.col[i]);
                    rec.num := colnum;

                    if not (ch in [eolch,eotch])
                    then begin
                           {for i := 1 to rec.num do
                           begin
                             if i<=colnum
                             then write (headers.col[i])
                             else write ('?');
                             write ('(',i,'):',rec.col[i]);
                             if true or (i mod 3 = 0) //i=rec.num
                             then writeln
                             else write ('|')
                           end;}
                           error ('length mismach @ '+strfromint(recnum+1)+
                                  ', ch: '+ch+' '+strfromint(ord(ch))+
                                  ', expected:'+strfromint(colnum)+
                                  ', found:'+strfromint(rec.num))
                         end
                  end
           end;

      if getheaders
      then headers := rec
      else with rec do
             for i := 1 to num do
               if length(col[i])>maxflen[i]
               then maxflen[i] := length(col[i]);

      eot := (ch=eotch) or (nextch=eotch) //patch for empty line on the end
    end
  end;

  procedure csvclose (var cf:csvfile);
  var f:text; i,max:integer;
  begin

    if outputheaders
    then with cf do
         begin
           assign (f,headersfile);
           append (f);
           writeln (f,plainname);
           writeln (f,'-------------');
           with headers do
           begin

             max := 0;
             for i := 1 to num do
               if maxflen[i]>max
               then max := maxflen[i];


             write (f,num:3,' ! ');
             if showfieldlengths
             then write (f,'#',max:3,' !')
             else write (f,'# !');

             writeln (f,' field name');
             for i := 1 to num do
             begin
               write (f,i:3);

               if showfieldlengths
               then write (f,' !  ',maxflen[i]:3,' !')
               else if (maxflen[i]=0) and (recnum<>0)
                    then write (f,' ! * !')
                    else write (f,' !   !');

               write (f,' ',col[i]);
               writeln (f)
             end
          end;
           writeln (f);
           close (f)
         end;
    close (cf.ft)
  end;

begin
  outputheaders := false
end.