format PE CONSOLE
entry start

section '.text' code readable executable

  printhelp:
        push    helptext
        call    [puts]
        jmp     fin
  start:
        ;push    30000
        ;call    [Sleep]
        mov     ebx,0  ; flag pro print retval
        call    [GetCommandLineA]  ; walk cmdline for args - program se bude volat jen z pøíkazové øádky, bez uvozovek kolem názvu => staèí hledat 2020h
  skip_exec_name:
        inc     eax
        mov     cx,[eax]
        cmp     cl,0
        jz      printhelp
        cmp     ch,0
        jz      printhelp
        cmp     cx,2020h
        jne     skip_exec_name
        add     eax,2    ; zkontrolovat že za 2020h neni 0?
        mov     esi,eax  ; v esi je ptr na lib_name, úplnì staèí projít a dát za nìj nulu
  skip_lib_name:
        inc     eax
        mov     cl,[eax]
        cmp     cl,0
        jz      printhelp
        cmp     cl,20h
        jne     skip_lib_name
        mov     [eax],BYTE 0
        inc     eax      ; zkontrolovat že za mezerou neni 0?
        mov     edi,eax  ; v edi je ptr na proc_name, projít a dát za nìj nulu
  skip_proc_name:
        inc     eax
        mov     cl,[eax]
        mov     ch,cl
        or      ch,20h
        cmp     ch,20h  ; pokud je cl 0 nebo 20h -> OK === cl | 20h == 20h
        jne     skip_proc_name
        cmp     cl,0
        jz      args_done
        mov     [eax],BYTE 0
        ;inc     eax
        mov     [ptrargs],eax
        ;dec     eax

; parse params - "..." znamená string (-> pushnout ptr na tento string v cmdline), 1A2Bh èíslo v hexu, [0-9]+ dekadické èíslo, P print eax, R print (char*)eax
  skip_args_to_end:
        inc     eax
        mov     cl,[eax]
        cmp     cl,0
        jnz     skip_args_to_end

  parse_args:   ; když procházíme argumenty zpátky, musíme vìdìt kde se zarazit. uložit si ptr kde zaèínají args do ptrargs
        dec     eax
        cmp     eax,[ptrargs]
        jbe     args_done
        mov     cl,[eax]
        cmp     cl,20h
        je      parse_args
        cmp     cl,'P'
        jne     parse_args_r
        mov     bl,1
        dec     eax
        jmp     parse_args
  parse_args_r:
        cmp     cl,'R'
        jne     parse_args_s
        mov     bh,1
        dec     eax
        jmp     parse_args
  parse_args_s:
        cmp     cl,'"'
        jne     parse_args_n
        mov     [eax],BYTE 0
  parse_args_s_loop:
        dec     eax
        mov     cl,[eax]
        cmp     cl,'"'
        jne     parse_args_s_loop
        inc     eax
        push    eax
        sub     eax,2
        jmp     parse_args
  parse_args_n:
        cmp     cl,'0'
        jb      printhelp
        cmp     cl,'9'
        ja      printhelp
        mov     edx,1
        and     ecx,000000ffh
        sub     cl,'0'
        mov     ebp,ecx
  parse_args_n_loop:
        dec     eax
        mov     cl,[eax]
        cmp     cl,'0'
        jb      parse_args_n_loop_end  ; pøi ' ' jmp loop_end jinak printhelp ?
        cmp     cl,'9'
        ja      parse_args_n_loop_end
        sub     cl,'0'
        imul    edx,10
        imul    ecx,edx
        add     ebp,ecx
        xor     ecx,ecx
        jmp     parse_args_n_loop
  parse_args_n_loop_end:
        push    ebp
        jmp     parse_args

  args_done:
        ; loadlibrary
        push    esi
        call    [LoadLibraryA]  ; TODO: schovat si HMODULE a na konci zavolat FreeLibrary
        test    eax,eax
        jz      libnotfound
        ; getprocaddress
        push    edi
        push    eax
        call    [GetProcAddress]
        test    eax,eax
        jz      procnotfound

        call    eax

        ; print retval - schovat si eax!
        mov     edi,eax
        cmp     bl,0
        jz      after_print_eax
        push    eax
        push    ftext
        call    [printf]
        add     esp,8
  after_print_eax:
        cmp     bh,0
        jz      fin
        push    edi
        call    [puts]
        add     esp,4
        jmp     fin
  libnotfound:
        push    esi
        push    libnftext
        call    [printf]
        add     esp,8
        jmp     fin
  procnotfound:
        push    esi
        push    edi
        push    procnftext
        call    [printf]
        add     esp,12
        ;jmp     fin

  fin:
        ; TODO: clean up

        push    0
        call    [ExitProcess]

section '.data' data readable writeable

  ftext db '0x%X',13,10,0
  helptext db 'Usage: myrundll.exe DLLNAME PROCNAME [ARGS ...] [P] [R]',13,10,'  ARGS can be: decimal numbers or strings enclosed in "double quotes"',13,10,'  P means print eax, R means print (char*)eax',13,10,'Example: myrundll.exe USER32.DLL MessageBoxA 0 "Message" "Title" 0',13,10,'         myrundll.exe shell32 ShellAboutA 0 "Hello" 0 0',13,10,'         myrundll.exe kernel32 WriteFile 7 "some text" 9 "    " 0',0
  libnftext db 'Error: library %s not found!',13,10,0
  procnftext db 'Error: function %s not found in library %s!',13,10,0
  ptrargs dd 0

section '.idata' import data readable writeable

  dd 0,0,0,RVA kernel_name,RVA kernel_table
  dd 0,0,0,RVA msvcrt_name,RVA msvcrt_table
  dd 0,0,0,0,0

  kernel_table:
    ExitProcess dd RVA _ExitProcess
    GetCommandLineA dd RVA _GetCommandLineA
    GetProcAddress dd RVA _GetProcAddress
    LoadLibraryA dd RVA _LoadLibraryA
    Sleep dd RVA _Sleep
    dd 0

  kernel_name db 'KERNEL32.DLL',0

  _ExitProcess dw 0
    db 'ExitProcess',0

  _GetCommandLineA dw 0
    db 'GetCommandLineA',0

  _GetProcAddress dw 0
    db 'GetProcAddress',0

  _LoadLibraryA dw 0
    db 'LoadLibraryA',0

  _Sleep dw 0
    db 'Sleep',0

  msvcrt_table:
    printf dd RVA _printf
    puts dd RVa _puts
    dd 0

  msvcrt_name db 'MSVCRT.DLL',0

  _printf dw 0
    db 'printf',0
  _puts dw 0
    db 'puts',0

section '.reloc' fixups data readable discardable       ; needed for Win32s
