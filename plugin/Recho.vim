" Recho.vim:   Report-Echo -- based completely on Decho.vim
" Maintainer:  Charles E. Campbell <NdrOchip@ScampbellPfamily.AbizM>
" Date:        Apr 13, 2011
" Version:     1d	NOT RELEASED
"
" Usage: {{{1
"   Recho "a string"
"   call Recho("another string")
"   let g:recho_bufname = "ANewRECHOBufName"
"   let g:recho_bufenter= 1    " tells Recho to ignore BufEnter, WinEnter,
"                              " WinLeave events while Recho is working
"   call Recho("one","thing","after","another")
"   RechoOn     : removes any first-column '"' from lines containing Recho
"   RechoOff    : inserts a '"' into the first-column in lines containing Recho
"   RechoMsgOn  : use echomsg instead of RECHO buffer
"   RechoMsgOff : turn debugging off
"   RechoRemOn  : turn remote Recho messaging on
"   RechoRemOff : turn remote Recho messaging off
"   RechoVarOn [varname] : use variable to write debugging messages to
"   RechoVarOff : turn debugging off
"   RechoTabOn  : turn debugging on (uses a separate tab)
"   RechoTabOff : turn debugging off
"
" GetLatestVimScripts: 120 1 :AutoInstall: Recho.vim
" GetLatestVimScripts: 1066 1 :AutoInstall: cecutil.vim

" ---------------------------------------------------------------------
" Load Once: {{{1
if exists("g:loaded_Recho") || &cp
 finish
endif
let g:loaded_Recho = "v21i"
let s:keepcpo      = &cpo
set cpo&vim

" ---------------------------------------------------------------------
"  Default Values For Variables: {{{1
if !exists("g:recho_bufname")
 let g:recho_bufname= "RECHO"
endif
if !exists("s:recho_depth")
 let s:recho_depth  = 0
endif
if !exists("g:recho_winheight")
 let g:recho_winheight= 5
endif
if !exists("g:recho_bufenter")
 let g:recho_bufenter= 0
endif
if !exists("g:rechomode")
 let s:RECHOWIN = 1
 let s:RECHOMSG = 2
 let s:RECHOVAR = 3
 let s:RECHOREM = 4
 let s:RECHOTAB = 5
 let g:rechomode= s:RECHOWIN
endif
if !exists("g:rechovarname")
 let g:rechovarname = "g:rechovar"
endif

" ---------------------------------------------------------------------
"  User Interface: {{{1
com! -nargs=+ -complete=expression Recho	call Recho(<args>)
com! -nargs=+ -complete=expression Dredir	call Dredir(<args>)
com! -nargs=0 Dhide    						call s:Dhide(1)
com! -nargs=0 Dshow    						call s:Dhide(0)
com! -nargs=? RechoSep						call RechoSep(<args>)
com! -nargs=? Rsep						    call RechoSep(<args>)
com! -nargs=0 RechoMsgOn					call s:RechoCtrlInit(s:RECHOMSG,expand("<sfile>"))
com! -nargs=0 RechoMsgOff					call s:RechoMsg(0)
com! -nargs=0 -range=% RechoOn				call RechoOn(<line1>,<line2>)
com! -nargs=0 -range=% RechoOff				call RechoOff(<line1>,<line2>)
if has("clientserver") && executable("gvim")
 com! -nargs=0 RechoRemOn					call s:RechoCtrlInit(s:RECHOREM,expand("<sfile>"))
 com! -nargs=0 RechoRemOff					call s:RechoRemote(0)
endif
com! -nargs=? RechoVarOn					call s:RechoCtrlInit(s:RECHOVAR,expand("<sfile>"),<args>)
com! -nargs=0 RechoVarOff					call s:RechoVarOff()
if v:version >= 700
 com! -nargs=? RechoTabOn                   call s:RechoCtrlInit(s:RECHOTAB,expand("<sfile>"))
 com! -nargs=? RechoTabOff                  set lz|call s:RechoTab(0)|set nolz
endif
com! -nargs=0 RechoPause					call RechoPause()
au Filetype Recho nmap <silent> <buffer> <F1> :setlocal noro ma<cr>

" ---------------------------------------------------------------------
" Recho: the primary debugging function: splits the screen as necessary and {{{1
"        writes messages to a small window (g:recho_winheight lines)
"        on the bottom of the screen
fun! Recho(...)
 
  " make sure that SaveWinPosn() and RestoreWinPosn() are available
  if !exists("g:loaded_cecutil")
   runtime plugin/cecutil.vim
   if !exists("g:loaded_cecutil") && exists("g:loaded_AsNeeded")
   	AN SWP
   endif
   if !exists("g:loaded_cecutil")
   	echoerr "***Recho*** need to load <cecutil.vim>"
	return
   endif
  endif

  " set up ctrl mode as user specified earlier
  call s:RechoCtrl()

  " open RECHO window (if rechomode is rechowin)
  if g:rechomode == s:RECHOWIN
   let swp   = SaveWinPosn(0)
   let curbuf= bufnr("%")
   if g:recho_bufenter
    let eikeep= &ei
	let eakeep= &ea
	set ei=BufEnter,WinEnter,WinLeave,ShellCmdPost,FocusGained noea
   endif
 
   " As needed, create/switch-to the RECHO buffer
   if !bufexists(g:recho_bufname) && bufnr("*/".g:recho_bufname."$") == -1
    " if requested RECHO-buffer doesn't exist, create a new one
    " at the bottom of the screen.
    exe "keepj sil! bot ".g:recho_winheight."new ".g:recho_bufname
    setlocal noswf
	keepj sil! %d
 
   elseif bufwinnr(g:recho_bufname) > 0
    " if requested RECHO-buffer exists in a window,
    " go to that window (by window number)
    exe "keepj ".bufwinnr(g:recho_bufname)."wincmd W"
    exe "res ".g:recho_winheight
 
   else
    " user must have closed the RECHO-buffer window.
    " create a new one at the bottom of the screen.
    exe "keepj sil bot ".g:recho_winheight."new"
    setlocal noswf
    exe "keepj b ".bufnr(g:recho_bufname)
   endif
 
   set ft=Recho
   setlocal noswapfile noro nobl
 
   "  make sure RECHO window is on the bottom
   wincmd J
  endif

  " Build Message
  let i  = 1
  let msg= ""
  while i <= a:0
   try
    exe "let msg=msg.a:".i
   catch /^Vim\%((\a\+)\)\=:E730/
    " looks like a:i is a list
    exe "let msg=msg.string(a:".i.")"
   endtry
   if i < a:0
    let msg=msg." "
   endif
   let i=i+1
  endwhile

  " Initialize message
  let smsg   = ""
  let idepth = 0
  while idepth < s:recho_depth
   let smsg   = "|".smsg
   let idepth = idepth + 1
  endwhile

  " Handle special characters (\t \r \n)
  " and append msg to smsg
  let smsg= smsg.strtrans(msg)
"  let i    = 1
"  while msg != ""
"   let chr  = strpart(msg,0,1)
"   let msg  = strpart(msg,1)
"   if char2nr(chr) < 32
"       let smsg = smsg.'^'.nr2char(64+char2nr(chr))
"   else
"    let smsg = smsg.chr
"   endif
"  endwhile

"  echomsg "g:rechomode=".g:rechomode
  if g:rechomode == s:RECHOMSG
   " display message with echomsg
   exe "echomsg '".substitute(smsg,"'","'.\"'\".'","ge")."'"

  elseif g:rechomode == s:RECHOVAR
   " "display" message by appending to variable named by g:rechovarname
   let smsg= substitute(smsg,"'","''","ge")
   if exists(g:rechovarname)
    exe "let ".g:rechovarname."= ".g:rechovarname.".'\n".smsg."'"
   else
    exe "let ".g:rechovarname."= '".smsg."'"
   endif

  elseif g:rechomode == s:RECHOREM
   " display message by appending it to remote RECHOREMOTE vim server
   let smsg= substitute(smsg,"\<esc>","\<c-v>\<esc>","ge")
   try
    call remote_send("RECHOREMOTE",':set ma fo-=at'."\<cr>".'Go'.smsg."\<esc>".':set noma nomod'."\<cr>")
   catch /^Vim\%((\a\+)\)\=:E241/
   	let g:rechomode= s:RECHOWIN
   endtry

  elseif g:rechomode == s:RECHOTAB
   " display message by appending it to the debugging tab window
   let eikeep= &ei
   let lzkeep= &lz
   set ei=all lz
   let g:rechotabcur = tabpagenr()
   exe "sil! tabn ".g:rechotabnr
   if !exists("t:rechotabpage")
	" looks like a new tab has been inserted -- look for a tab having t:rechotabpage
	let g:rechotabnr= 1
	silent! tabn 1
	while !exists("t:rechotabpage")
	 let g:rechotabnr= g:rechotabnr + 1
	 if g:rechotabnr > tabpagenr("$")
	  " re-generate the "Recho Tab" tab -- looks like it was closed!
	  call s:RechoTab(1)
      exe "tabn".g:rechotabnr
	  break
	 endif
     exe "tabn".g:rechotabnr
    endwhile
   endif

   " check that the debugging tab still has a debugging window left in it; use it
   " if present
   let dbgwin= bufwinnr(bufname("Recho Tab"))
   if dbgwin == -1
	" looks like only non-debugging windows are left in what had been the debugging tab.
	" Regenerate it.
	if exists("t:rechotabpage")
	 unlet t:rechotabpage
	endif
	call s:RechoTab(1)
    exe "tabn".g:rechotabnr
   else
	exe dbgwin."wincmd w"
   endif

   " append message to "Recho Tab" window in the debugging tab
   " echomsg "appending message to tab#".tabpagenr()
   setlocal ma noro
   call setline(line("$")+1,smsg)
   setlocal noma nomod
   " restore tab# to original user tab
   exe "tabn ".g:rechotabcur
   " echomsg "returning to tab#".tabpagenr()
   let &ei= eikeep
   let &lz= lzkeep

  else
   " Write Message to RECHO buffer
   setlocal ma
   keepjumps $
   keepjumps let res= append("$",smsg)
   setlocal nomod
 
   " Put cursor at bottom of RECHO window, then return to original window
   exe "res ".g:recho_winheight
   keepjumps norm! G
   if exists("g:recho_hide") && g:recho_hide > 0
    setlocal hidden
    q
   endif
   keepjumps wincmd p
   if exists("swp")
    call RestoreWinPosn(swp)
   endif
 
   if g:recho_bufenter
    let &ei= eikeep
	let &ea= eakeep
   endif
  endif
endfun

" ---------------------------------------------------------------------
"  Rfunc: just like Recho, except that it also bumps up the depth {{{1
"         It also appends a "{" to facilitate use of %
"         Usage:  call Rfunc("functionname([opt arglist])")
fun! Rfunc(...)
  " Build Message
  let i  = 1
  let msg= ""
  while i <= a:0
   exe "let msg=msg.a:".i
   if i < a:0
    let msg=msg." "
   endif
   let i=i+1
  endwhile
  let msg= msg." {"
  call Recho(msg)
  let s:recho_depth= s:recho_depth + 1
  let s:Rfunclist_{s:recho_depth}= substitute(msg,'[( \t].*$','','')
endfun

" ---------------------------------------------------------------------
"  Rret: just like Recho, except that it also bumps down the depth {{{1
"        It also appends a "}" to facilitate use of %
"         Usage:  call Rret("functionname [optional return] [: optional extra info]")
fun! Rret(...)
  " Build Message
  let i  = 1
  let msg= ""
  while i <= a:0
   exe "let msg=msg.a:".i
   if i < a:0
    let msg=msg." "
   endif
   let i=i+1
  endwhile
  let msg= msg." }"
  call Recho("return ".msg)
  if s:recho_depth > 0
   let retfunc= substitute(msg,'\s.*$','','e')
   if  retfunc != s:Rfunclist_{s:recho_depth}
   	echoerr "Rret: appears to be called by<".s:Rfunclist_{s:recho_depth}."> but returning from<".retfunc.">"
   endif
   unlet s:Rfunclist_{s:recho_depth}
   let s:recho_depth= s:recho_depth - 1
  endif
endfun

" ---------------------------------------------------------------------
" RechoOn: {{{1
fun! RechoOn(line1,line2)
  let ickeep= &ic
  set noic
  let swp    = SaveWinPosn(0)
  let rechopat = '\<R\%(echo\|func\|redir\|ret\|echo\%(Msg\|Rem\|Tab\|Var\)O\%(n\|ff\)\)\>'
  if search(rechopat,'cnw') == 0
   echoerr "this file<".expand("%")."> does not contain any Recho/Rfunc/Rret commands or function calls!"
  else
   exe "sil! keepj ".a:line1.",".a:line2.'g/'.rechopat.'/s/^"\+//'
  endif
  call RestoreWinPosn(swp)
  let &ic= ickeep
endfun

" ---------------------------------------------------------------------
" RechoOff: {{{1
fun! RechoOff(line1,line2)
  let ickeep= &ic
  set noic
  let swp=SaveWinPosn(0)
  let swp= SaveWinPosn(0)
  exe "sil! keepj ".a:line1.",".a:line2.'g/\<R\%(echo\|func\|redir\|ret\|echo\%(Msg\|Rem\|Tab\|Var\)O\%(n\|ff\)\)\>/s/^[^"]/"&/'
  call RestoreWinPosn(swp)
  let &ic= ickeep
endfun

" ---------------------------------------------------------------------
" RechoDepth: allow user to force depth value {{{1
fun! RechoDepth(depth)
  let s:recho_depth= a:depth
endfun

" ---------------------------------------------------------------------
" s:RechoCtrlInit: initializes RechoCtrl variables {{{2
"    One of the RechoCMDOn commands calls this function with the associated CMD's mode
"    Instead of being immediate, the command's effect is deferred until the first Recho call.
"    Recho() calls RechoCtrl(), which in turn sets up the CMD's mode.
fun! s:RechoCtrlInit(mode,...)
  let s:RechoCtrlmode = a:mode
  if a:0 > 0
   let s:RechoCtrlfname= a:1
  endif
  if a:0 > 1
   let s:RechoCtrlargs = a:2
  elseif exists("s:RechoCtrlargs")
   unlet s:RechoCtrlargs
  endif
endfun

" ---------------------------------------------------------------------
" RechoCtrl: sets up the deferred CMD's mode {{{2
"            Also see RechoCtrlInit()
fun! s:RechoCtrl()

  if !exists("s:RechoCtrlmode")
   return
	
  elseif s:RechoCtrlmode == s:RECHOWIN
   let g:rechomode= s:RECHOWIN

  elseif s:RechoCtrlmode == s:RECHOMSG
   call s:RechoMsg(1,s:RechoCtrlfname)

  elseif s:RechoCtrlmode == s:RECHOVAR
   if exists("s:RechoCtrlargs")
	call s:RechoVarOn(s:RechoCtrlfname,s:RechoCtrlargs)
   else
	call s:RechoVarOn(s:RechoCtrlfname)
   endif

  elseif s:RechoCtrlmode == s:RECHOREM
   call s:RechoRemote(1,s:RechoCtrlfname)

  elseif s:RechoCtrlmode == s:RECHOTAB
   set lz
   call s:RechoTab(1,s:RechoCtrlfname)
   set nolz

  else
   echoerr "(s:RechoCtrl) bad mode#".s:RechoCtrlmode
  endif

  if exists("s:RechoCtrlmode") |unlet s:RechoCtrlmode |endif
  if exists("s:RechoCtrlfname")|unlet s:RechoCtrlfname|endif
  if exists("s:RechoCtrlargs") |unlet s:RechoCtrlargs |endif

endfun

" ---------------------------------------------------------------------
" s:RechoMsg: {{{2
fun! s:RechoMsg(onoff,...)
"  call Dfunc("s:RechoMsg(onoff=".a:onoff.") a:0=".a:0)
  if a:onoff
   let g:rechomode = s:RECHOMSG
   let g:rechofile = (a:0 > 0)? a:1 : ""
  else
   let g:rechomode= s:RECHOWIN
  endif
"  call Dret("s:RechoMsg")
endfun

" ---------------------------------------------------------------------
" Rhide: (un)hide RECHO buffer {{{1
fun! <SID>Rhide(hide)

  if !bufexists(g:recho_bufname) && bufnr("*/".g:recho_bufname."$") == -1
   " RECHO-buffer doesn't exist, simply set g:recho_hide
   let g:recho_hide= a:hide

  elseif bufwinnr(g:recho_bufname) > 0
   " RECHO-buffer exists in a window, so its not currently hidden
   if a:hide == 0
   	" already visible!
    let g:recho_hide= a:hide
   else
   	" need to hide window.  Goto window and make hidden
	let curwin = winnr()
	let rechowin = bufwinnr(g:recho_bufname)
    exe bufwinnr(g:recho_bufname)."wincmd W"
	setlocal hidden
	q
	if rechowin != curwin
	 " return to previous window
     exe curwin."wincmd W"
	endif
   endif

  else
   " The RECHO-buffer window is currently hidden.
   if a:hide == 0
	let curwin= winnr()
    exe "sil bot ".g:recho_winheight."new"
    setlocal bh=wipe
    exe "b ".bufnr(g:recho_bufname)
    exe curwin."wincmd W"
   else
   	let g:recho_hide= a:hide
   endif
  endif
  let g:recho_hide= a:hide
endfun

" ---------------------------------------------------------------------
" Rredir: this function performs a debugging redir by temporarily using {{{1
"         register a in a redir @a of the given command.  Register a's
"         original contents are restored.
"   Usage:  Rredir(["string","string",...,]"cmd")
fun! Rredir(...)
  if a:0 <= 0
   return
  endif
  let icmd = 1
  while icmd < a:0
   call Recho(a:{icmd})
   let icmd= icmd + 1
  endwhile
  let cmd= a:{icmd}

  " save register a, initialize
  let keep_rega = @a
  let v:errmsg  = ''

  " do the redir of the command to the register a
  try
   redir @a
    exe "keepj sil ".cmd
  catch /.*/
   let v:errmsg= substitute(v:exception,'^[^:]\+:','','e')
  finally
   redir END
   if v:errmsg == ''
   	let output= @a
   else
   	let output= v:errmsg
   endif
   let @a= keep_rega
  endtry

  " process output via Recho()
  while output != ""
   if output =~ "\n"
   	let redirline = substitute(output,'\n.*$','','e')
   	let output    = substitute(output,'^.\{-}\n\(.*$\)$','\1','e')
   else
   	let redirline = output
   	let output    = ""
   endif
   call Recho("redir<".cmd.">: ".redirline)
  endwhile
endfun

" ---------------------------------------------------------------------
" RechoSep: puts a separator with counter into debugging output {{{2
fun! RechoSep(...)
"  call Dfunc("RechoSep() a:0=".a:0)
  if !exists("s:rechosepcnt")
   let s:rechosepcnt= 1
  else
   let s:rechosepcnt= s:rechosepcnt + 1
  endif
  let eikeep= &ei
  set ei=all
  call Recho("--sep".s:rechosepcnt."--".((a:0 > 0)? " ".a:1 : ""))
  let &ei= eikeep
"  call Dret("RechoSep")
endfun

" ---------------------------------------------------------------------
" RechoPause: puts a pause-until-<cr> into operation; will place a {{{2
"             separator into the debug output for reporting
fun! RechoPause()
"  call Dfunc("RechoPause()")
  redraw!
  call RechoSep("(pause)")
  call inputsave()
  call input("Press <cr> to continue")
  call inputrestore()
"  call Dret("RechoPause")
endfun

 " ---------------------------------------------------------------------
 " RechoRemote: supports sending debugging to a remote vim {{{1
if has("clientserver") && executable("gvim")
 fun! s:RechoRemote(mode,...)
   if a:mode == 0
    " turn remote debugging off
    if g:rechomode == s:RECHOREM
    	let g:rechomode= s:RECHOWIN
    endif
 
   elseif a:mode == 1
    " turn remote debugging on
    if g:rechomode != s:RECHOREM
 	 let g:rechomode= s:RECHOREM
    endif
	let g:rechofile= (a:0 > 0)? a:1 : ""
    if serverlist() !~ '\<RECHOREMOTE\>'
 "   " start up remote Recho server
 "   call Recho("start up RECHOREMOTE server")
     if has("win32") && executable("start")
      call system("start gvim --servername RECHOREMOTE")
	 else
      call system("gvim --servername RECHOREMOTE")
	 endif
     while 1
      try
 	   call remote_send("RECHOREMOTE",':silent set ft=Recho fo-=at'."\<cr>")
       call remote_send("RECHOREMOTE",':file [Recho\ Remote\ Server]'."\<cr>")
 	   call remote_send("RECHOREMOTE",":put ='--------------------'\<cr>")
 	   call remote_send("RECHOREMOTE",":put ='Remote Recho Window'\<cr>")
 	   call remote_send("RECHOREMOTE",":put ='--------------------'\<cr>")
 	   call remote_send("RECHOREMOTE","1GddG")
	   call remote_send("RECHOREMOTE",':set noswf nomod nobl nonu ch=1 fo=n2croql nosi noai'."\<cr>")
 	   call remote_send("RECHOREMOTE",':'."\<cr>")
 	   call remote_send("RECHOREMOTE",':set ft=Recho'."\<cr>")
 	   call remote_send("RECHOREMOTE",':syn on'."\<cr>")
 	   break
      catch /^Vim\%((\a\+)\)\=:E241/
 	   sleep 200m
      endtry
     endwhile
    endif
 
   else
    echohl Warning | echomsg "RechoRemote(".a:mode.") not supported" | echohl None
   endif
 
 endfun
endif

" ---------------------------------------------------------------------
"  RechoVarOn: turu debugging-to-a-variable on.  The variable is given {{{1
"  by the user;   RechoVarOn [varname]
fun! s:RechoVarOn(...)
  let g:rechomode= s:RECHOVAR
  
  if a:0 > 0
   let g:rechofile= a:1
   if a:2 =~ '^g:'
    exe "let ".a:2.'= ""'
   else
    exe "let g:".a:2.'= ""'
   endif
  else
   let g:rechovarname= "g:rechovar"
  endif
endfun

" ---------------------------------------------------------------------
" RechoVarOff: {{{1
fun! s:RechoVarOff()
  if exists("g:rechovarname")
   if exists(g:rechovarname)
    exe "unlet ".g:rechovarname
   endif
  endif
  let g:rechomode= s:RECHOWIN
endfun

 " --------------------------------------------------------------------
 " RechoTab: {{{1
if v:version >= 700
 fun! s:RechoTab(mode,...)
"   call Dfunc("RechoTab(mode=".a:mode.") a:0=".a:0)
   echomsg "RechoTab(mode=".a:mode.") a:0=".a:0
 
   if a:mode
    let g:rechomode = s:RECHOTAB
	let g:rechofile = (a:0 > 0)? a:1 : ""
    let rechotabcur = tabpagenr()
"	echomsg "rechotabcur#".rechotabcur." g:rechotabnr".(exists("g:rechotabnr")? "#".g:rechotabnr : "-doesn't exist")
    if !exists("g:rechotabnr")
	 let eikeep= &ei
	 set ei=all
	 tabnew
	 file Recho\ Tab
	 let t:rechotabpage= 1
	 let g:rechotabnr  = tabpagenr()
"	 echomsg "setting g:rechotabnr#".g:rechotabnr." rechofile<".g:rechofile.">"
	 setlocal ma
	 put ='---------'
	 put ='Recho Tab'.g:rechofile
	 put ='---------'
	 norm! 1GddG
	 let &ei          = ""
	 set ft=Recho
	 set ei=all
	 setlocal noma nomod nobl noswf ch=1 fo=n2croql
	 exe "tabn ".rechotabcur
	 let &ei= eikeep
"	 echomsg "return to tab#".rechotabcur.": file<".expand("%").">"
	endif
   else
    let g:rechomode= s:RECHOWIN
   endif
 
 "  call Dret("RechoTab")
 endfun
endif

" ---------------------------------------------------------------------
"  End Plugin: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo

" ---------------------------------------------------------------------
"  vim: ts=4 fdm=marker
