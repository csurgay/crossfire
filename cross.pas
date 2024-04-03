uses dos,crt,graph;
var gd,gm:integer;

const
  maxnmen=3; {max number of moving enemies (+1*level)}
  maxendelay=3; {delay for enemy, 1 at nen=level+2}
  defaultneeddelay=20; {delay for all}
  maxadjustdelay=10;
  maxlives=3;
  bonuslife=3000;
  maxfire=35; {-3*level}
  maxbullets=0; {max number of enemy bullets (+2*level)}
  pbullet:array[1..4] of integer=(-1,0,1,4); {prob of bullet (+0*level)}
  mindbullet:array[1..4] of integer=(60,25,10,5); {min delay between bullets}
                                                          {(-0*level)}
const
  lb=20; {left bias}
  dh=17; dv=16; {horizontal, vertical diameter of blocks}
  d1=15; d2=8; {diameter, half diameter of corridors}
  dd=14; {dangerous distance}
  bonix:array[1..4] of integer=(3*d1+2*dh+1,5*d1+4*dh+1,5*d1+4*dh+1,3*d1+2*dh+1);
  boniy:array[1..4] of integer=(4*d1+3*dv+1,4*d1+3*dv+1,3*d1+2*dv+1,3*d1+2*dv+1);
  bonox:array[1..4] of integer=(3*d1+2*dh+1,5*d1+4*dh+1,5*d1+4*dh+1,3*d1+2*dh+1);
  bonoy:array[1..4] of integer=(4*d1+4*dv,4*d1+4*dv,2*d1+2*dv,2*d1+2*dv);
  bonbo:array[1..4] of integer=(100,200,400,800);
  bonst:array[1..4] of string[3]=('100','200','400','800');
  maxalone=200;
  escores:array[1..4] of integer = (20,30,40,50);
  escoress:array[1..4] of string[2] = ('20','30','40','50');

var
  IBO,ISH,IAM, {Image-Bonus,Image-Ship,Image-Ammo}
  IEM:pointer; {Image-Empty}
  IX:array[1..2] of pointer; {Image-Explosion type 1/2}
  IE:array[1..4] of pointer; {Image-Enemy1,2,3}

procedure arena;
var i,j:integer;
begin
  setcolor(1);
  for i:=1 to 7 do for j:=1 to 6 do
    rectangle(lb+i*d1+(i-1)*dh,j*d1+(j-1)*dv,lb+i*(d1+dh)-1,j*(d1+dv)-1);
  setcolor(3);
end;

procedure abort(s:string);
begin
  write(s); readln; halt(1);
end;

procedure image(f:string);
var
  t:text;
  s:string;
  i,j,c:integer;
begin
  cleardevice;
  assign(t,'patterns.cro'); reset(t);
    repeat readln(t,s) until (s=f) or eof(t);
    if eof(t) then abort(f+' is missing from patterns.cro');
    readln(t,c);
    readln(t);
    for i:=1 to 15 do begin
      readln(t,s);
      for j:=1 to 15 do begin
        s:=copy(s,3,length(s)-2);
        if copy(s,1,2)='  ' then begin end
        else if copy(s,1,2)='²²' then begin putpixel(j,i,c); end
        else abort(f+'corrupted in patterns.cro');
      end;
    end;
  close(t);
end;

procedure images;
begin
  image('bonus'); getmem(IBO,imagesize(1,1,d1,d1-1)); getimage(1,1,d1,d1-1,IBO^);
  image('ship');  getmem(ISH,imagesize(1,1,d1,d1)); getimage(1,1,d1,d1,ISH^);
  image('ammo');  getmem(IAM,imagesize(1,1,d1,d1)); getimage(1,1,d1,d1,IAM^);
  image('explosion1');  getmem(IX[1],imagesize(1,1,d1,d1)); getimage(1,1,d1,d1,IX[1]^);
  image('explosion2');  getmem(IX[2],imagesize(1,1,d1,d1)); getimage(1,1,d1,d1,IX[2]^);
  image('empty');  getmem(IEM,imagesize(1,1,d1,d1-1)); getimage(1,1,d1,d1-1,IEM^);
  image('enemy1'); getmem(IE[1],imagesize(1,1,d1,d1)); getimage(1,1,d1,d1,IE[1]^);
  image('enemy2'); getmem(IE[2],imagesize(1,1,d1,d1)); getimage(1,1,d1,d1,IE[2]^);
  image('enemy3'); getmem(IE[3],imagesize(1,1,d1,d1)); getimage(1,1,d1,d1,IE[3]^);
  image('enemy4'); getmem(IE[4],imagesize(1,1,d1,d1)); getimage(1,1,d1,d1,IE[4]^);
end;

function sgn(v:integer):integer;
begin
  if v>0 then sgn:=1 else if v=0 then sgn:=0 else sgn:=-1;
end;

var
  i,j,r,dx,dy,code:integer;
  ch:char;
  spx,spy,isx,isy,svx,svy,ifx,ify,fvx,fvy,fpx,fpy:integer;
  el, {which life}
  epx,epy, {position}
  evx,evy, {velocity}
  espx,espy, {starting position}
  es1x,es1y,es2x,es2y, {1st and 2nd starting direction}
  est, {state:0-park,1-started,2-active}
  ewait, {enemy waits for a moment before active}
  dbullet
  :array[1..11] of integer;
    {after started it can go back,after active it cannot}
  died,bingo,jam:boolean; {they succeed, bullet found, crowded enemies}
  newammopos,isbonus:boolean; {new ammo pos needed}
  ax,ay:integer; {ammo pos}
  allfires,lastallfires,bonus,swallowdelay:integer;
  nen,nmen:integer; {number of enemies, number of moving enemies}
  edelay,endelay,bspeed:integer; {enemy delay, bullet speed}
  lives,maxammo,ammo,level,ammosound,ammosounddir:integer;
  score,hiscore,lastscore:longint;
  alone:integer; {the time being alone}
  nbul:integer; {number of active bullets}
  bpx,bpy,bvx,bvy:array[1..1000] of integer;
  nx,actxt:integer; {number of explosions, actual explosion type}
  xpx,xpy,xd,xt:array[1..11] of integer; {explosion pos:x/y and duration}
  adelay:longint; {delay for all}
  needsound:boolean;

procedure newexplosion(x,y:integer);
begin
  inc(nx); xpx[nx]:=x; xpy[nx]:=y; xd[nx]:=30; xt[nx]:=actxt; actxt:=3-actxt;
end;

procedure clearexplosion;
var i:integer;
begin
  for i:=1 to nx-1 do begin
    xpx[i]:=xpx[i+1];
    xpy[i]:=xpy[i+1];
    xd[i]:=xd[i+1];
    xt[i]:=xt[i+1];
  end;
  dec(nx);
end;

procedure showns;
var
  s:string;
  i:integer;
begin
  str(nbul,s); s:='B'+copy('00',1,2-length(s))+s;
  for i:=0 to 1 do  putimage(282+i*d1-d2,128,IEM^,0);
  outtextxy(282,128,s);
  str(nen,s); s:='E'+copy('00',1,2-length(s))+s;
  for i:=0 to 1 do  putimage(282+i*d1-d2,138,IEM^,0);
  outtextxy(282,138,s);
end;

procedure kill(p:integer);
var i:integer;
begin
  if el[p]>0 then begin
    if needsound then begin
      sound(50); delay(20); nosound; delay(5);
      sound(50); delay(20); nosound; delay(5);
    end;
    putimage(lb+epx[p],epy[p],IEM^,0);
    putimage(lb+spx,spy,ISH^,0);
    if est[p]=2 then newexplosion(epx[p],epy[p])
    else newexplosion(espx[p]+d1*es1x[p],espy[p]+d1*es1y[p]);
  end;
  inc(el[p]);
  dec(nmen);
  est[p]:=0;
  if el[p]>4 then begin
    for i:=p to nen-1 do begin
      epx[i]:=epx[i+1];
      epy[i]:=epy[i+1];
      evx[i]:=evx[i+1];
      evy[i]:=evy[i+1];
      espx[i]:=espx[i+1];
      espy[i]:=espy[i+1];
      es1x[i]:=es1x[i+1];
      es1y[i]:=es1y[i+1];
      es2x[i]:=es2x[i+1];
      es2y[i]:=es2y[i+1];
      el[i]:=el[i+1];
      est[i]:=est[i+1];
      ewait[i]:=ewait[i+1];
      dbullet[i]:=dbullet[i+1];
    end;
    dec(nen); showns;
    if (nen<=level+2) then endelay:=1;
    if endelay=0 then {!!! bspeed:=2};
  end
  else begin
    epx[p]:=espx[p];
    epy[p]:=espy[p];
    evx[p]:=0;
    evy[p]:=0;
    dbullet[p]:=0;
    putimage(lb+epx[p],epy[p],IE[el[p]]^,0);
  end;
end;

procedure initship;
begin
  spx:=4*(d1+dh); spy:=5*(d1+dv);
  isx:=17; isy:=17; svx:=0; svy:=0;
  putimage(lb+spx,spy,ISH^,0);
end;

procedure initenemies;
var i,j:integer;
begin
  j:=1;
  for i:=2 to 7 do begin
    espx[j]:=i*d1+(i-1)*dh+1; espy[j]:=0;
    es1x[j]:=-1; es1y[j]:=0;
    es2x[j]:=0; es2y[j]:=1;
    inc(j);
  end;
  for i:=1 to 3 do begin
    espx[j]:=0; espy[j]:=i*2*d1+(i*2-1)*dv;
    es1x[j]:=0; es1y[j]:=-1;
    es2x[j]:=1; es2y[j]:=0;
    inc(j);
  end;
  for i:=1 to 2 do begin
    espx[j]:=7*(d1+dh); espy[j]:=(i*2+1)*d1+i*2*dv;
    es1x[j]:=0; es1y[j]:=-1;
    es2x[j]:=-1; es2y[j]:=0;
    inc(j);
  end;
  nen:=11; nmen:=11; edelay:=0; endelay:=maxendelay; bspeed:=1;
  for i:=1 to 11 do begin
    el[i]:=0; kill(i);
  end;
end;

procedure standing;
var
  i:integer;
  s:string;
begin
  if score>=lastscore+bonuslife then begin
    inc(lives);
    lastscore:=score;
  end;
  if score>hiscore then hiscore:=score;
  outtextxy(282,35,'Score');
  str(score,s); s:=copy('000000',1,6-length(s))+s;
  for i:=0 to 3 do putimage(244+i*d1,46,IEM^,0);
  outtextxy(282,46,s);
  outtextxy(282,1,'Hiscore');
  str(hiscore,s); s:=copy('000000',1,6-length(s))+s;
  for i:=0 to 3 do putimage(244+i*d1,12,IEM^,0);
  outtextxy(282,12,s);

  outtextxy(282,97,'Level');
  str(level,s); s:=copy('00',1,2-length(s))+s;
  for i:=0 to 1 do  putimage(282+i*d1-d2,108,IEM^,0);
  outtextxy(282,108,s);

  outtextxy(282,159,'Ships');
  str(lives,s); s:=copy('00',1,2-length(s))+s;
  for i:=0 to 1 do putimage(282+i*d1-d2,170,IEM^,0);
  outtextxy(282,170,s);

  if lives=0 then begin
    for i:=0 to 4 do putimage(100+i*d1,93,IEM^,0);
    outtextxy(139,97,'GAME OVER');
  end;
end;

procedure chartest;
var ch:char;
begin
  for ch:=#32 to #255 do begin write(ord(ch),':',ch); readln; end;
  ch:='|';
  repeat
    if keypressed then begin
      ch:=readkey;
      writeln(ord(ch),':',ch);
    end;
  until ch=#27;
end;

procedure colortest;
var i:integer;
begin
  for i:=0 to 15 do begin
    setcolor(i);
    outtextxy(100,100,'Color:'+chr(i+48));
    readln;
  end;
end;

const
  ds:array[1..5,1..2] of integer=((-1,0),(0,-1),(1,0),(0,1),(0,0));
  dkeys:array[1..5] of char=('j','i','l','k',' ');

var
  autopilot,cheated:boolean;
  k:integer;
  nde:integer;                 {number of dangerous enemies}
  dei:array[1..11] of integer; {de id}
  ded:array[1..11] of integer; {de distance}
  d:integer; {distance}
  actshot:boolean;
  pd,dd1,dd2:array[-1..1,-1..1] of boolean; {possible & desired direction 1/2}
  isdd1,isdd2:boolean;
  s,name:string;
  t:text;
  year,month,day,dayofweek:word;
  hour,minute,second,sec100:word;
  hour1,minute1,second1,sec1001:word;
  adjustdelay:integer;
  actdelay,needdelay,prevadelay:word;

BEGIN
  {chartest;}
  randomize;
  writeln('CrossFire, Copyright (C) 1995, Peter Csurgay');
  delay(1000);
  if paramcount=0 then begin
    writeln('Usage: cross ''name''');
    halt(1);
  end;
  val(paramstr(paramcount),needdelay,code);
  if code<>0 then needdelay:=defaultneeddelay;
  name:=paramstr(1);
  assign(t,'history.cro'); {$I-} reset(t); {$I+}
  hiscore:=0;
  if ioresult=0 then begin
    while not eof(t) do begin
      readln(t,s); s:=copy(s,pos(#9,s)+1,length(s)-pos(#9,s))+' ';
      if (copy(s,1,length(name))=name)
      and (pos('cheated',s)=0) then begin
        s:=copy(s,length(name)+2,length(s)-length(name)-1);
        s:=copy(s,1,pos(' ',s)-1);
        val(s,score,code);
        if score>hiscore then hiscore:=score;
      end;
    end;
    close(t);
  end;
  if name='robot' then autopilot:=true else autopilot:=false;
  gd:=cga; gm:=cgac0;
  initgraph(gd,gm,'');
  {colortest;}
  settextjustify(centertext,toptext);
  images;
  cleardevice;
  setcolor(1);
  outtextxy(160,1,'CROSSFIRE');
  outtextxy(160,180,'Copyright (C) 1995, Peter Csurgay');
  outtextxy(160,120,'shoot:          move:');
  outtextxy(160,135,'  e               i  ');
  outtextxy(160,145,'s   f           j   l');
  outtextxy(160,150,'  d               k  ');
  settextjustify(lefttext,toptext);
  for i:=1 to 4 do begin
    putimage(30,8+i*20,IE[i]^,0);
    outtextxy(55,12+i*20,'- '+escoress[i]+' points');
  end;
  putimage(180,8+1*20,IBO^,0);
  outtextxy(205,12+1*20,'- bonus');
  putimage(180,8+2*20,IAM^,0);
  outtextxy(205,12+2*20,'- ammo');
  outtextxy(177,12+3*20,'SPC');
  outtextxy(205,12+3*20,'- stop moving');
  outtextxy(177,12+4*20,'ENT');
  outtextxy(205,12+4*20,'- robot mode');
  settextjustify(centertext,toptext);
  spx:=0; spy:=12; svx:=1;
  while not keypressed and not autopilot do begin
    putimage(spx,spy,ISH^,1);
    for i:=1 to 2 do begin
      putimage(180,8+1*20,IBO^,1);
      delay(40);
      putimage(180,8+2*20,IAM^,1);
    end;
    putimage(spx,spy,ISH^,1);
    inc(spx,svx); if (spx>=320-d1) or (spx<0) then svx:=-svx;;
  end;
  setcolor(3);
  while keypressed do ch:=readkey;

  lives:=maxlives; score:=0; lastscore:=0; level:=1;
  actxt:=1; cheated:=false; needsound:=true;
  adelay:=needdelay; adjustdelay:=maxadjustdelay;

  repeat
    cleardevice;

    for i:=1 to 4 do putimage(lb+bonix[i],boniy[i],IBO^,0);

    initship;
    alone:=maxalone;
    maxammo:=maxfire-(level-1)*3; if maxammo<15 then maxammo:=15;
    ammo:=maxammo; newammopos:=true;
    bonus:=0; isbonus:=false; allfires:=0; lastallfires:=0; swallowdelay:=0;
    initenemies;
    nx:=0;
    nde:=0; actshot:=false;
    arena;
    standing;
    nbul:=0; showns;

    died:=false;
    ifx:=17; ify:=17; fvx:=0; fvy:=0;
    ch:='|';
    repeat
      if adjustdelay=maxadjustdelay then gettime(hour1,minute1,second1,sec1001);
      dec(adjustdelay);
      delay(adelay);
      inc(edelay); if edelay>endelay then edelay:=0;
      if keypressed then ch:=readkey;

      { AUTOPILOT }
      if autopilot then begin
        pd[-1,0]:=true; pd[0,-1]:=true; pd[1,0]:=true; pd[0,1]:=true; pd[0,0]:=true;
        dd1[-1,0]:=false; dd1[0,-1]:=false; dd1[1,0]:=false; dd1[0,1]:=false; dd1[0,0]:=false;
        dd2[-1,0]:=false; dd2[0,-1]:=false; dd2[1,0]:=false; dd2[0,1]:=false; dd2[0,0]:=false;
        if spx=dh+d1 then pd[-1,0]:=false;
        if spy=dv+d1 then pd[0,-1]:=false;
        if spx=6*(dh+d1) then pd[1,0]:=false;
        if spy=5*(dv+d1) then pd[0,1]:=false;
        if spx mod (dh+d1)<>0 then begin pd[0,-1]:=false; pd[0,1]:=false; end;
        if spy mod (dv+d1)<>0 then begin pd[-1,0]:=false; pd[1,0]:=false; end;

        { AUTOPILOT: DANGEROUS ENEMIES }
        nde:=0;
        for i:=1 to nen do begin
          dx:=spx-epx[i];
          dy:=spy-epy[i];
          if dx<d1 then d:=dy else d:=dx;
          if (est[i]>0) and ((abs(dx)<2*d1) or (abs(dy)<2*d1)) then begin
            inc(nde);
            j:=1; while (d>ded[j]) and (j<nde) do inc(j);
            for k:=nde downto j+1 do begin
              ded[k]:=ded[k-1]; dei[k]:=dei[k-1];
            end;
            ded[j]:=d; dei[j]:=i;
          end;
        end;

        { AUTOPILOT: COULD GO FOR BONUS }
        if (ammo>10) and isbonus
        and (spx mod (dh+d1)=0) and (spy mod (dv+d1)=0) then begin
          dx:=bonox[bonus]-spx;
          dy:=bonoy[bonus]-spy;
          if (abs(dx)<dh-1) and (dy<>0) then begin
            if dx<>0 then dd1[-sgn(dx),0]:=true;
            if dx<>0 then dd2[sgn(dx),0]:=true;
          end
          else if (abs(dx)=dh-1) and (dy<>0) then begin
            if dy<>0 then dd1[0,sgn(dy)]:=true;
            if dx<>0 then dd2[sgn(dx),0]:=true;
          end
          else begin
            if dx<>0 then dd1[sgn(dx),0]:=true;
            if dy<>0 then dd1[0,sgn(dy)]:=true;
            dd2[0,-1]:=true; dd2[0,1]:=true;
          end;
        end;
        { AUTOPILOT: CLOSEST TO SHOOT }
        if not actshot {!!!or (ded[dei[1]]<2*d1)} then begin
          if (nde>0) then begin
            dx:=spx-spx mod (d1+dh)+svx*svx*(svx+1) div 2*(d1+dh)-epx[dei[1]];
            dy:=spy-spy mod (d1+dv)+svy*svy*(svy+1) div 2*(d1+dv)-epy[dei[1]];
            dx:=dx-abs(dx) div (7*(endelay+1)) *evx[dei[1]];
            dy:=dy-abs(dy) div (7*(endelay+1)) *evy[dei[1]];
            if abs(dx)<d2 then
              if dy<0 then ch:='d' else ch:='e';
            if abs(dy)<d2 then
              if dx<0 then ch:='f' else ch:='s';
            if ch in ['d','e','f','s'] then begin
              actshot:=true;
              dec(nde);
              for k:=1 to nde do begin
                ded[k]:=ded[k+1]; dei[k]:=dei[k+1];
              end;
            end;
          end;
          if (nen=1) and ((bonus<4) or (bonus=4) and isbonus) then begin
            if isbonus then begin
              ch:='|';
              actshot:=false;
            end
            else begin
              case ch of 's':s:='edf';'e':s:='sdf';'d':s:='sef';'f':s:='sed';
              else s:='sedf'; end;
              ch:=s[random(length(s))+1];
              actshot:=true;
            end;
          end;
        end;
        { AUTOPILOT: SHOULD GO FOR AMMO }
        if (ammo<=10) then begin
          dx:=ax-spx;
          dy:=ay-spy;
          if {(abs(dx)<dh) and} (abs(dy)>=dv+d1)
          and (spx div (dh+d1)=ax div (d1+dh))
          and not pd[0,sgn(dy)] then begin
            if (spx mod (dh+d1)+ax mod (dh+d1)-dd>dh)
            then begin dd1[1,0]:=true; dd2[-1,0]:=true; end
            else begin dd1[-1,0]:=true; dd2[1,0]:=true; end
          end
          else if {(abs(dy)<dv) and} (abs(dx)>=dh+d1)
          and (spy div (dv+d1)=ay div (d1+dv))
          and not pd[sgn(dx),0] then begin
            if (spy mod (dv+d1)+ay mod (d1+dv)-dd>dv)
            then begin dd1[0,1]:=true; dd2[0,-1]:=true; end
            else begin dd1[0,-1]:=true; dd2[0,1]:=true; end
          end
          else begin
            if dx<>0 then dd1[sgn(dx),0]:=true;
            if dy<>0 then dd1[0,sgn(dy)]:=true;
          end;
        end;
        { AUTOPILOT: MUST AVOID COLLISION }
        for i:=1 to nen do begin
          dx:=spx+3*svx-epx[i]-evx[i]*3;
          dy:=spy+3*svy-epy[i]-evy[i]*3;
          if (abs(dx)<2*d1) and (abs(dy)<2*d1) then begin
            pd[-sgn(dx),0]:=false; pd[0,-sgn(dy)]:=false; pd[0,0]:=false;
          end;
        end;
        { AUTOPILOT: MUST AVOID BULLETS }
        for i:=1 to nbul do begin
          dx:=spx+svx+d2-bpx[i]-bspeed*bvx[i]*d1;
          dy:=spy+svy+d2-bpy[i]-bspeed*bvy[i]*d1;
          if (abs(dx)<2*d1) and (abs(dy)<2*d1) then begin
            pd[-sgn(dx),0]:=false; pd[0,-sgn(dy)]:=false;
          end;
        end;
        { AUTOPILOT: WHERE TO GO THEN? }
        for i:=-1 to 1 do for j:=-1 to 1 do dd1[i,j]:=dd1[i,j] and pd[i,j];
        for i:=-1 to 1 do for j:=-1 to 1 do dd2[i,j]:=dd2[i,j] and pd[i,j];
        isdd1:=false; for i:=1 to 5 do isdd1:=isdd1 or dd1[ds[i,1],ds[i,2]];
        isdd2:=false; for i:=1 to 5 do isdd2:=isdd2 or dd2[ds[i,1],ds[i,2]];
        if (ch='|') then begin
          if isdd1 then begin
            r:=random(5)+1;
            for i:=1 to 5 do begin
              if dd1[ds[r,1],ds[r,2]] then ch:=dkeys[r];
              inc(r); if r>5 then r:=1;
            end;
          end
          else if isdd2 then begin
            r:=random(5)+1;
            for i:=1 to 5 do begin
              if dd2[ds[r,1],ds[r,2]] then ch:=dkeys[r];
              inc(r); if r>5 then r:=1;
            end;
          end
          else if pd[0,0] and (random(100)=0) then begin
            ch:=' ';
          end
          else if pd[svx,svy] and (random(100)<>0) then begin
          end
          else begin
            r:=random(5)+1;
            for i:=1 to 5 do begin
              if pd[ds[r,1],ds[r,2]] then ch:=dkeys[r];
              inc(r); if r>5 then r:=1;
            end;
          end;
        end;
        if (ch='j') and (svx=1) or (ch='l') and (svx=-1)
        or (ch='i') and (svy=1) or (ch='k') and (svy=-1) then
          actshot:=false;
      end;

      if ch='i' then begin isy:=-1; isx:=0; end
      else if ch='k' then begin isy:=1; isx:=0; end
      else if ch='j' then begin isx:=-1; isy:=0; end
      else if ch='l' then begin isx:=1; isy:=0; end
      else if ch=' ' then begin isx:=0; isy:=0; end
      else if ch='e' then begin ify:=-1; ifx:=0; end
      else if ch='d' then begin ify:=1; ifx:=0; end
      else if ch='s' then begin ifx:=-1; ify:=0; end
      else if ch='f' then begin ifx:=1; ify:=0; end
      else if ch=#13 then begin autopilot:=not autopilot; cheated:=true; end
      else if ch='0' then begin needdelay:=0; end
      else if ch='1' then begin needdelay:=5; end
      else if ch='2' then begin needdelay:=10; end
      else if ch='3' then begin needdelay:=20; end
      else if ch='4' then begin needdelay:=40; cheated:=true; end
      else if ch='5' then begin needdelay:=80; cheated:=true; end
      else if ch='6' then begin needdelay:=160; cheated:=true; end
      else if ch='7' then begin needdelay:=320; cheated:=true; end
      else if ch='8' then begin needdelay:=640; cheated:=true; end
      else if ch='9' then begin needdelay:=3000; cheated:=true; end
      else if ch='*' then begin needdelay:=defaultneeddelay; end
      else if ch='+' then begin if needdelay>0 then dec(needdelay); end
      else if ch='-' then begin if needdelay<10000 then inc(needdelay); cheated:=true; end
      else if ch=#19 then begin needsound:=not needsound; end;
      if ch=#27 then autopilot:=false else ch:='|';

      { AMMO }
      r:=random(2);
      if (ammo<=10) and newammopos then begin
        newammopos:=false; ammosound:=5000; ammosounddir:=1;
        if r=0 then begin
          ax:=(random(6)+1)*(dh+d1); ay:=random(4*(dv+d1))+dv+d1;
        end
        else begin
          ax:=random(5*(dh+d1))+dh+d1; ay:=(random(5)+1)*(dv+d1);
        end;
      end;
      if ammo<=10 then begin
        putimage(lb+ax,ay,IAM^,1);
        if ammosound mod 200=0 then begin
          if needsound then begin sound(ammosound); delay(5); nosound; end;
        end;
        inc(ammosound,ammosounddir*20);
        if ammosound<=5000 then ammosounddir:=1;
        if ammosound>=6000 then ammosounddir:=-1;
      end;

      { BONUS }
      if isbonus then putimage(lb+bonox[bonus],bonoy[bonus],IBO^,1);
      if swallowdelay>0 then begin
        setwritemode(1);
        putimage(lb+bonox[bonus]-d2,bonoy[bonus],IEM^,0);
        putimage(lb+bonox[bonus]+d2-1,bonoy[bonus],IEM^,0);
        outtextxy(lb+bonox[bonus]+d2,bonoy[bonus]+2,bonst[bonus]);
        putimage(lb+spx,spy,ISH^,0);
        setwritemode(0);
        dec(swallowdelay);
        if swallowdelay=0 then begin
          putimage(lb+bonox[bonus]-d2,bonoy[bonus],IEM^,0);
          putimage(lb+bonox[bonus]+d2-1,bonoy[bonus],IEM^,0);
          putimage(lb+spx,spy,ISH^,0);
        end;
      end;

      { EXPLOSIONS }
      for i:=1 to nx do begin
        putimage(lb+xpx[i],xpy[i],IX[xt[i]]^,1);
        dec(xd[i]);
        if xd[i]=0 then begin
          putimage(lb+xpx[i],xpy[i],IEM^,0);
          putimage(lb+spx,spy,ISH^,0);
          clearexplosion;
        end;
      end;

      { SHIP: NEW VELOCITY VECTOR }
      if isx+isy<2 then begin
        if (isy<>0) and (spx mod (d1+dh)=0) or
           (isx<>0) and (spy mod (d1+dv)=0) or
           (spx mod (d1+dh)=0) and (spy mod (d1+dv)=0) then begin
          svx:=isx; svy:=isy; isx:=17; isy:=17;
        end;
      end;

      { SHIP: MOVES }
      if svx+svy<>0 then begin
        if (spx+svx<d1+dh) or (spx+svx>6*(d1+dh)) then svx:=0
        else if (spy+svy<d1+dv) or (spy+svy>5*(d1+dv)) then svy:=0
        else begin
          inc(spx,svx); inc(spy,svy); putimage(lb+spx,spy,ISH^,0);
          if (ammo<=10) and (abs(spx-ax)<d1) and (abs(spy-ay)<d1) then begin
            putimage(lb+ax,ay,IEM^,0);
            putimage(lb+spx,spy,ISH^,0);
            ammo:=maxammo; newammopos:=true;
            if needsound then begin
              for i:=1500 to 2500 do sound(i); nosound;
            end;
          end;
          if isbonus and (abs(spx-bonox[bonus])<d1)
          and (abs(spy-bonoy[bonus])<d1) then begin
            inc(score,bonbo[bonus]);
            swallowdelay:=50;
            lastallfires:=allfires;
            isbonus:=false;
            if needsound then begin
              for i:=1500 to 2500 do begin sound(i); end; nosound;
            end;
            standing;
          end;
        end;
      end;

      { SHIP: TRY TO FIRE }
      if (ifx+ify<2) and (ammo>0) then begin
        if ((ifx=0) and (spx mod (d1+dh)=0) or
           (ify=0) and (spy mod (d1+dv)=0)) and (fvx+fvy=0) then begin
          fvx:=ifx; fvy:=ify; ifx:=17; ify:=17;
          fpx:=spx+d2+fvx*d2; fpy:=spy+d2+fvy*d2;
          dec(ammo); inc(allfires);
          if allfires=lastallfires+12 then begin
            isbonus:=not isbonus;
            if isbonus then inc(bonus);
            if bonus>4 then isbonus:=false;
            lastallfires:=allfires;
            if isbonus then begin
              putimage(lb+bonix[bonus],boniy[bonus],IEM^,0);
              if needsound then begin
                for i:=3000 to 4000 do begin sound(i); end; nosound;
              end;
            end
            else if bonus<5 then begin
              putimage(lb+bonox[bonus],bonoy[bonus],IEM^,0);
              putimage(lb+spx,spy,ISH^,0);
              putimage(lb+bonix[bonus],boniy[bonus],IBO^,0);
            end;
          end;
        end;
      end;

      { SHIP: FIRE MOVES }
      if fvx+fvy<>0 then begin
        i:=1; bingo:=false;
        repeat
          if (nen>0) and (abs(epx[i]+d2-fpx)<=d2) and (abs(epy[i]+d2-fpy)<d2) then begin
            inc(score,escores[el[i]]); standing; kill(i); bingo:=true;
          end;
          inc(i);
        until (i>nen) or bingo;
        if bingo or (fpx<d1) or (fpx>=7*(d1+dh))
        or (fpy<d1) or (fpy>5*(d1+dv)+d1) then begin
          setcolor(0); line(lb+fpx,fpy,lb+fpx+14*fvx,fpy+14*fvy); setcolor(3);
          fvx:=0; fvy:=0; actshot:=false;
        end
        else begin
          line(lb+fpx+7*fvx,fpy+7*fvy,lb+fpx+14*fvx,fpy+14*fvy);
          setcolor(0); line(lb+fpx,fpy,lb+fpx+6*fvx,fpy+6*fvy); setcolor(3);
        end;
        inc(fpx,7*fvx); inc(fpy,7*fvy);
      end;

      { BULLETS }
      for i:=1 to nbul do begin
        if (abs(spx+d2-bpx[i])<d2) and (abs(spy+d2-bpy[i])<d2) then begin
          died:=true;
        end;
        if (bpx[i]<d1) or (bpx[i]>7*(d1+dh))
        or (bpy[i]<d1) or (bpy[i]>5*(d1+dv)) then begin
          setcolor(0);
          line(lb+bpx[i]-bvx[i],bpy[i]-bvy[i],lb+bpx[i]+(2+3*bspeed)*bvx[i],bpy[i]+(2+3*bspeed)*bvy[i]);
          setcolor(3);
          for j:=i to nbul-1 do begin
            bpx[j]:=bpx[j+1]; bpy[j]:=bpy[j+1];
            bvx[j]:=bvx[j+1]; bvy[j]:=bvy[j+1];
          end;
          dec(nbul); showns;
        end
        else begin
          line(lb+bpx[i]+bvx[i],bpy[i]+bvy[i],lb+bpx[i]+(2+3*bspeed)*bvx[i],bpy[i]+(2+3*bspeed)*bvy[i]);
          setcolor(0);
          line(lb+bpx[i]-bvx[i],bpy[i]-bvy[i],lb+bpx[i]+bspeed*bvx[i],bpy[i]+bspeed*bvy[i]);
          setcolor(3);
        end;
        inc(bpx[i],bspeed*bvx[i]); inc(bpy[i],bspeed*bvy[i]);
      end;

      { ENEMIES }
      if nen>0 then begin

        { ENEMIES: START MOVING }
        i:=random(nen)+1;
        if (evx[i]+evy[i]=0) and ((nmen<maxnmen+1*level) or (est[i]>0)) then begin
          if est[i]=0 then begin
            inc(nmen); evx[i]:=es1x[i]; evy[i]:=es1y[i]; est[i]:=1;
          end
          else begin
            dec(ewait[i]);
            r:=random(4);
            if (ewait[i]=0) or (nen<=maxnmen+1*level) then
              if (r>0) or (nen<=maxnmen+1*level) then begin
                evx[i]:=es2x[i]; evy[i]:=es2y[i]; est[i]:=2;
              end
              else begin evx[i]:=-es1x[i]; evy[i]:=-es1y[i]; end;
          end;
        end;

        { ENEMIES: MOVE }
        if edelay=0 then for i:=1 to nen do begin

          { DELAY OF NEXT BULLET }
          if dbullet[i]=0 then r:=random(100) else begin
            r:=101;
            dec(dbullet[i]);
          end;

          { MOVE, JAM? }
          if (est[i]>0) then begin
            inc(epx[i],evx[i]); inc(epy[i],evy[i]);
            jam:=false;
            for j:=1 to nen do begin
              if (j<>i) and (abs(epx[i]-epx[j])<d1)
              and (abs(epy[i]-epy[j])<d1) then begin
                jam:=true;
                dec(epx[i],evx[i]); dec(epy[i],evy[i]);
                if (epx[i]>=dh+d1) and (epx[i]<=7*(dh+d1)-dv)
                and (epy[i]>=dv+d1) and (epy[i]<=6*(dv+d1)-dv) then begin
                  evx[i]:=-evx[i]; evy[i]:=-evy[i];
                end;
              end;
            end;
            putimage(lb+epx[i],epy[i],IE[el[i]]^,0);

            dx:=sgn(spx-epx[i]); dy:=sgn(spy-epy[i]);

            if ((epx[i] mod (d1+dh)=0) or (epy[i] mod (d1+dv)=0))
            and (nbul<maxbullets+2*level) and (est[i]=2) then begin
              if r<pbullet[el[i]]+0*level then begin
                dbullet[i]:=mindbullet[el[i]]-0*level;
                inc(nbul); showns;
                if epx[i] mod (d1+dh)<>0 then dy:=0;
                if epy[i] mod (d1+dv)<>0 then dx:=0;
                if (dx<>0) and (dy<>0) then begin
                  r:=random(2); if r=0 then dx:=0 else dy:=0;
                end;
                bvx[nbul]:=dx; bvy[nbul]:=dy;
                bpx[nbul]:=epx[i]+d2+dx*d2; bpy[nbul]:=epy[i]+d2+dy*d2;
              end;
            end;

            if not jam then begin

              {IF JUST ARRIVED BACK TO ITS STARTING POSITION}
              if (epx[i]=espx[i]) and (epy[i]=espy[i]) then begin
                dec(nmen); est[i]:=0; evx[i]:=0; evy[i]:=0;
              end;
              if (abs(spx-epx[i])<dd) and (abs(spy-epy[i])<dd) then died:=true;
              if (epx[i] mod (d1+dh)=0) and (epy[i] mod (d1+dv)=0) then begin
                if est[i]=1 then begin
                  evx[i]:=0; evy[i]:=0; ewait[i]:=random(5);
                end
                else begin
                  evx[i]:=sgn(spx-epx[i]);
                  evy[i]:=sgn(spy-epy[i]);
                  if (evx[i]<>0) and (evy[i]<>0) then begin
                    r:=random(2);
                    if r=0 then evx[i]:=0 else evy[i]:=0;
                  end;
                end;
              end;
            end;
          end;
        end;
      end;

      if (nen=0) then dec(alone);

      { DIED }
      if died then begin
        for i:=1 to 5 do begin
          putimage(lb+spx,spy,IX[actxt]^,0);
          actxt:=3-actxt;
          delay(300);
        end;
        delay(500);
        dec(lives); standing;
        if lives>0 then begin
          died:=false;
          nmen:=0;
          ammo:=maxammo; newammopos:=true;
          for i:=1 to nen do begin
            putimage(lb+epx[i],epy[i],IEM^,0);
            epx[i]:=espx[i]; epy[i]:=espy[i]; est[i]:=0; evx[i]:=0; evy[i]:=0;
          end;
          putimage(lb+spx,spy,IEM^,0);
          putimage(lb+ax,ay,IEM^,0);
          setcolor(0);
          for i:=1 to nbul do
            line(lb+bpx[i],bpy[i],lb+bpx[i]+5*bvx[i],bpy[i]+5*bvy[i]);
          setcolor(3);
          nbul:=0; showns;
          for i:=1 to nen do putimage(lb+epx[i],epy[i],IE[el[i]]^,0);
          initship;
          nde:=0; actshot:=false;
        end;
      end;
      if adjustdelay=0 then begin
        adjustdelay:=maxadjustdelay;
        gettime(hour,minute,second,sec100);
        actdelay:=(hour-hour1);
        actdelay:=actdelay*60+(minute-minute1);
        actdelay:=actdelay*60+(second-second1);
        actdelay:=actdelay*100+(sec100-sec1001);
        if actdelay<needdelay then begin
          {!!!prevadelay:=adelay div 4+1;}
          inc(adelay);
        end;
        if actdelay>needdelay then begin
          {!!!prevadelay:=adelay div 5+1;}
          dec(adelay);
        end;
        if adelay<0 then adelay:=0;
      end;
    until (ch=#27) or died or (nen=0) and (alone=0);
    if nen=0 then inc(level);
    standing;
    if died or (nen=0) then delay(2000);

  until (ch=#27) or died;
  getdate(year,month,day,dayofweek);
  gettime(hour,minute,second,sec100);
  assign(t,'history.cro'); {$I-} append(t); {$I+} if ioresult<>0 then rewrite(t);
  write(t,month,'.',day,'. ',hour,':',minute,#9,name,':',score);
  if cheated then write(t,' (cheated)');
  if died then writeln(t) else writeln(t,' (aborted)');
  close(t);
  while keypressed do ch:=readkey;
  if died and not autopilot then ch:=readkey;
  while keypressed do ch:=readkey;
  closegraph;
END.
