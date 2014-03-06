" synchk.vim : creates a syntax-check file
"   Author: Charles E. Campbell
"   Date:   Jun 05, 2013
"   Version: 1d	ASTRO-ONLY
"redraw!|call DechoSep()|call inputsave()|call input("Press <cr> to continue")|call inputrestore()
" ---------------------------------------------------------------------
"  Load Once: {{{1
if &cp || exists("g:loaded_synchk")
 finish
endif
let g:loaded_synchk= "v1d"
let s:keepcpo      = &cpo
set cpo&vim
"DechoRemOn

" =====================================================================
" Public Interface: {{{1
com! -nargs=0 -range=%			MakeSynChk		<line1>,<line2>call s:MakeSynChk()
com! -nargs=0 -range=%			SynChk			call s:SynChk()
com! -nargs=+ -complete=file  	ManyMakeSynChk	call s:ManyMakeSynChk(<f-args>)
com! -nargs=+ -complete=file  	ManySynChk		call s:ManySynChk(<f-args>)

" =====================================================================
" Functions: {{{1

" ---------------------------------------------------------------------
" s:ManyMakeSynChk: make syntax check files for filename(s) {{{2
fun! s:ManyMakeSynChk(...)
"  call Dfunc("s:ManyMakeSynChk(...) a:0=".a:0)
  let curdir = fnameescape(getcwd())
  let i      = 1
  while i <= a:0
"   call Decho("a:".i."<".a:{i}.">")
   if a:{i} =~ '/'
    let fnames = glob(a:{i})
   else
    let fnames = glob(curdir."/".a:{i})
   endif
   let fnamelist = split(fnames,"\n")
   for fname in fnamelist
"	call Decho("MakeSynChk'ing<".fname.">")
	exe "sil! e ".fname
    %MakeSynChk
   endfor
   let i= i + 1
  endwhile
"  call Dret("s:ManyMakeSynChk")
endfun

" ---------------------------------------------------------------------
" s:ManySynChk: check against syntax-check files for filename(s) {{{2
"               stops on first failure to pass the syntax check
fun! s:ManySynChk(...)
"  call Dfunc("s:ManySynChk(...) a:0=".a:0)
  let curdir = fnameescape(getcwd())
"  call Decho("curdir<".curdir.">")
  let i= 1
  while i <= a:0
"   call Decho("a:".i."<".a:{i}.">")
   if a:{i} =~ '/'
    let fnames = glob(a:{i})
   else
    let fnames = glob(curdir."/".a:{i})
   endif
   let fnamelist = split(fnames,"\n")
   for fname in fnamelist
"	call Decho("SynChk'ing<".fname.">")
	exe "sil! e ".fname
	%SynChk
	if !s:good
"     call Dret("s:ManySynChk")
	 return
	endif
   endfor
   let i= i + 1
  endwhile
  if !exists("s:faillist")
   echo "Failed: no checks performed"
  elseif empty(s:faillist)
   echomsg "all passed"
  else
   echomsg "Failed: ".string(s:faillist)
  endif
"  call Dret("s:ManySynChk")
endfun

" ---------------------------------------------------------------------
" MakeSynChk: {{{2
fun! s:MakeSynChk() range
"  call Dfunc("MakeSynChk() [".a:firstline.",".a:lastline."]")
  let nameroot   = expand("%:r")
  let nameext    = expand("%:e")
  let namesynchk = s:SynChkFilename(nameroot,nameext)
  let s:faillist = []
"  call Decho("namesynchk<".namesynchk.">")

  let vekeep     = &ve
  let lzkeep     = &lz
  set ve=all lz

  let curtab     = tabpagenr()
  tabnew
  let synchktab  = tabpagenr()
"  call Decho("(tab#".synchktab.") exe file ".fnameescape(namesynchk))
  exe "file ".fnameescape(namesynchk)
"  call Decho("synchktab#".synchktab.": file<".namesynchk.">")

  " pad synchktab with blank lines when needed
  let iline= a:firstline
  if line("$") == 1 && iline > line("$")
"   call Decho("padding with a blank line: line$=".line("$")." iline=".iline)
   call setline(line("$"),'')
  endif
  while iline > line("$")
"   call Decho("padding with a blank line: line$=".line("$")." iline=".iline)
   call setline(line("$")+1,'')
  endwhile
"  call Decho("done padding: line$=".line("$")." iline=".iline)

  " determine sum of all highlighting groups used by every character on each line
  " It was creating a "hash" code based on synID().  However, changes to the associated
  " syntax file also cause lots of changes to this hash because the syntax highlighting
  " IDs can change en masse.
  " Was using               : let synchk= synchk + synID(line("."),col("."),1)
  " SynChkHash() uses hashing with synIDattr(synID(line("."),col("."),1),"name")
  let iline= a:firstline
  while iline <= a:lastline
   exe "tabn ".curtab
   exe iline
   let synchk= s:SynChkHash()
"   call Decho(printf("synchk=%9d line#%4d: %s",synchk,line("."),getline(".")))
   exe "tabn ".synchktab
   call setline(iline,string(synchk))
   let iline= iline + 1
  endwhile
  silent wq!

  " restore options
  let &ve= vekeep
  let &lz= lzkeep

  echomsg "made synchk file<".namesynchk.">"
"  call Dret("MakeSynChk")
endfun

" ---------------------------------------------------------------------
" s:SynChk: returns 1 if passed, 0 if failed {{{2
"           returns same in s:good
fun! s:SynChk() range
"  call Dfunc("s:SynChk() [".a:firstline.",".a:lastline."]")

  " get name of previously generated synchk file
  let nameroot   = expand("%:r")
  let nameext    = expand("%:e")
  let namesynchk = s:SynChkFilename(nameroot,nameext)
"  call Decho("namesynchk<".namesynchk.">")
  if !exists("s:faillist")
   let s:faillist = []
  endif
  if !filereadable(namesynchk)
   call add(s:faillist,nameroot.".".nameext)
   echohl WarningMsg
   echon "***warning***"
   echohl Normal
   echon  " file<".namesynchk."> isn't readable"
"   call Dret("s:SynChk() : file not readable")
   return
  endif

  let vekeep = &ve
  let lzkeep = &lz
  set ve=all lz

  " curtab   : current file to be syntax checked
  " synchktab: previously stored syntax checked file
  let curtab     = tabpagenr()
  exe "sil! tabe ".fnameescape(namesynchk)
  let synchktab  = tabpagenr()
"  call Decho("(SynChk) curtab#".curtab." synchktab#".synchktab)

  " determine hash of all highlighting syntax names used by every character on each line
  let iline= a:firstline
  let good = 1
  while iline <= a:lastline
"   call Decho("exe tabn ".curtab)
   exe "tabn ".curtab
   exe iline
   let synchk= s:SynChkHash()
"   call Decho("exe tabn ".synchktab)
   exe "tabn ".synchktab

   " compare stored synchk with the synchk that was just computed
   let svdsynchk= getline(iline) + 0
   if svdsynchk != synchk
	let good= 0
    if !exists("s:didrechoremon")
"	 call Decho("(SynChk) performing RechoRemOn")
     let s:didrechoremon= 1
     RechoRemOn
    endif
    exe "tabn ".curtab
	call Recho(printf("(failed synchk) %s#%4d: %s",expand("%"),iline,getline(iline)))
   endif
"   call Decho(printf("%s#%4d: synchk=%9d svdsynchk=%9d %s",expand("%"),iline,synchk,svdsynchk,(good? "passed" : "FAILED")))

   let iline= iline + 1
  endwhile

  " now remove synchk tab
  exe "tabn ".synchktab
  sil! q!

  " restore options
  let &ve= vekeep
  let &lz= lzkeep

  " report
"  call Decho("report: ".expand("%")." ".(good? "passed" : "failed"))
  if good
   echomsg printf("%15s: passed",expand("%"))
  else
   echomsg printf("%15s: failed",expand("%"))
   call add(s:faillist,nameroot.".".nameext)
  endif

  let s:good= good
"  call Dret("s:SynChk ".good.": ".(good? "passed" : "failed"))
  return good
endfun

" ---------------------------------------------------------------------
" s:SynChkFilename: {{{2
fun! s:SynChkFilename(nameroot,nameext)
"  call Dfunc("s:SynChkFilename(nameroot<".a:nameroot."> nameext<".a:nameext.">)")
  let nameroot= a:nameroot
  let namepath= ""
  if nameroot =~ '/'
   let namepath= substitute(a:nameroot,'^\(.*/\)\([^/]\+\)$','\1','')
   let nameroot= substitute(a:nameroot,'^\(.*/\)\([^/]\+\)$','\2','')
  endif
  if !isdirectory(namepath."synchk")
"   call Decho("making directory<".namepath."synchk".">")
   call mkdir(namepath."synchk")
  endif
  let namesynchk = namepath."synchk/".nameroot."_".a:nameext.".synchk"
"  call Dret("s:SynChkFilename <".namesynchk.">")
  return namesynchk
endfun

" ---------------------------------------------------------------------
" s:SynChkHash: computes hash based upon the syntax id name {{{2
"               at the current cursor position.
"               Hashing is automatically reset whenever
"                    the filename changes
"                 or the line number in the file changes
"               All syntax id names on a line are hashed together.
fun! s:SynChkHash()
"  call Dfunc("s:SynChkHash()")
  if !exists("s:synchkfile") || !exists("s:synchkline") || s:synchkfile != expand("%") || s:synchkline != line(".")
"   call Decho("(SynChkHash) resetting hash")
   let s:synchkfile = expand("%")
   let s:synchkline = line(".")
  endif
  let hash = 0

  norm! 0
"  call Decho(printf("(SynChkHash) tab#%2d:line#%4d: %s",tabpagenr(),line("."),getline(".")))
  let key = 0
  while 1
   let synname = synIDattr(synID(line("."),col("."),1),"name")
"   """ call Decho("col#".col(".").": synname<".synname."> len=".strlen(synname))

   " following loop implements a hash
   let i =0
   while i < strlen(synname)
	let prvkey = key
	let key    = char2nr(synname[i])
	if hash > 536870912
	 let hash= xor(hash/1024,and(hash,31)) " hash>>10 ^ (hash&31)
	endif
 	let hash = xor(hash,key)
	let hash = 8*hash
	let hash = hash + prvkey
	if hash < 0
	 let hash= -hash
	endif

"	""" call Decho(printf("       synname[%2d]<%s> key=%3d prvkey=%3d hash=%d",i,synname[i],key,prvkey,hash))
	let i= i + 1
   endwhile

   if virtcol(".") >= virtcol("$")
"	""" call Decho("    i=".i.": end-of-line")
	break
   endif
   norm! l
  endwhile

  if hash < 0
   let hash= -hash
  endif
"  call Dret("s:SynChkHash ".hash)
  return hash
endfun

" =====================================================================
"  Restore: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" vim: ts=4 fdm=marker
