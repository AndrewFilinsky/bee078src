@Echo Off

Echo Deleting temporary files...

IF exist *.bak del *.bak
IF exist *.tpu del *.tpu
IF exist *.tpp del *.tpp
IF exist *.tfa del *.tfa
IF exist *.$$$ del *.$$$
IF exist *.~*  del *.~*
IF exist *.dcu del *.dcu
IF exist *.drc del *.drc
IF exist *.dsm del *.dsm
IF exist *.obj del *.obj
IF exist *.res del *.res
IF exist *.map del *.map
IF exist *.pif del *.pif
IF exist *.Bee del *.Bee
REM IF exist *.Rar del *.Rar
REM IF exist *.Opt del *.Opt
REM IF exist *.exe del *.exe
