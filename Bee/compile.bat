@echo off

  call clear.bat
  del  temp\Bee.exe
  del  distribution\Bee.exe
  
@echo @ 
@echo @ Compile Bee.exe ...
@echo @ 

  cd source
  dcc32 Bee.dpr
  cd ..

  copy temp\Bee.exe distribution\Bee.exe
  
  call clear.bat
  